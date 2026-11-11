import base64
import hashlib
import io
import secrets
from datetime import UTC, datetime
from urllib.parse import urlsplit
from uuid import uuid4

import qrcode
from fastapi import HTTPException
from sqlalchemy import exists, select

from app.models.business import AuditEvent
from app.models.health import HealthEvent
from app.models.public_verification import CodeRevocation, SlaughterCode
from app.models.registry import AnimalProfile, RegistryReceipt
from app.services.idempotency import lock_request
from app.services.registration import audit
from app.services.registry import require_record


def manage(session, species, label, principal):
    record = require_record(session, species, label)
    if principal.role != "admin" and record.registered_by != principal.operator_id:
        raise HTTPException(403, "Only the registering operator/admin can manage verification codes")
    return record


def origin(settings):
    value = settings.public_origin.rstrip("/")
    parsed = urlsplit(value)
    try:
        if parsed.port is not None and parsed.port < 1:
            raise ValueError("Port must be positive")
    except ValueError as exc:
        raise HTTPException(503, "Invalid public origin port") from exc
    if (
        parsed.scheme not in ("https", "http")
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or any(ord(c) < 33 for c in value)
        or parsed.query
        or parsed.fragment
        or parsed.path
    ):
        raise HTTPException(503, "Configure a canonical public HTTPS origin before issuing QR codes")
    if parsed.scheme == "http" and parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise HTTPException(503, "Public verification requires HTTPS")
    return value


def issue(session, species, label, principal, key, settings):
    manage(session, species, label, principal)
    profile = session.get(AnimalProfile, (species, label))
    if profile is None or profile.lifecycle != "slaughtered":
        raise HTTPException(409, "A server-recorded slaughter is required")
    url = origin(settings) + "/verify/" + secrets.token_urlsafe(settings.public_token_bytes)
    code = SlaughterCode(
        id=str(uuid4()),
        species=species,
        animal_id=label,
        token_sha256=hashlib.sha256(url.rsplit("/", 1)[1].encode()).hexdigest(),
        issued_by=principal.operator_id,
        request_key=key,
        created_at=datetime.now(UTC),
    )
    qr = qrcode.QRCode(box_size=settings.qr_box_size, border=settings.qr_border)
    qr.add_data(url)
    qr.make(fit=True)
    buffer = io.BytesIO()
    qr.make_image().save(buffer, format="PNG")
    session.add(code)
    audit(session, species, label, principal.operator_id, "slaughter_code_issued", {"code_id": code.id})
    session.flush()
    return {
        "code_id": code.id,
        "species": species.value,
        "animal_id": label,
        "url": url,
        "qr_png_base64": base64.b64encode(buffer.getvalue()).decode(),
        "created_at": code.created_at.isoformat(),
        "verification_level": "registry_record_only",
    }


def revoke(session, species, label, code_id, reason, principal):
    manage(session, species, label, principal)
    lock_request(session, "qr_revoke", code_id)
    if not reason.strip():
        raise HTTPException(422, "Revocation reason required")
    code = session.get(SlaughterCode, code_id)
    if code is None or (code.species, code.animal_id) != (species, label):
        raise HTTPException(404, "Verification code not found")
    if session.get(CodeRevocation, code_id):
        raise HTTPException(409, "Code is already revoked")
    now = datetime.now(UTC)
    session.add(
        CodeRevocation(code_id=code_id, actor_id=principal.operator_id, reason=reason, revoked_at=now)
    )
    audit(
        session,
        species,
        label,
        principal.operator_id,
        "slaughter_code_revoked",
        {"code_id": code_id, "reason": reason},
    )
    session.flush()
    return {"code_id": code_id, "revoked": True, "revoked_at": now.isoformat()}


def code_list(session, species, label, principal):
    manage(session, species, label, principal)
    codes = session.scalars(
        select(SlaughterCode)
        .where(SlaughterCode.species == species, SlaughterCode.animal_id == label)
        .order_by(SlaughterCode.created_at.desc())
    )
    result = []
    for code in codes:
        receipt = session.get(RegistryReceipt, (code.issued_by, code.request_key))
        if receipt is None:
            raise HTTPException(503, "Verification receipt is missing")
        result.append({**receipt.response, "revoked": session.get(CodeRevocation, code.id) is not None})
    return result


def public_record(session, token):
    if not 43 <= len(token) <= 86 or any(
        c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in token
    ):
        return None
    code = session.scalar(
        select(SlaughterCode).where(SlaughterCode.token_sha256 == hashlib.sha256(token.encode()).hexdigest())
    )
    if code is None or session.get(CodeRevocation, code.id):
        return None
    terminal = session.scalar(
        select(AuditEvent).where(
            AuditEvent.species == code.species,
            AuditEvent.animal_id == code.animal_id,
            AuditEvent.action == "animal_slaughtered",
        )
    )
    if terminal is None:
        return None
    # Only unsuperseded examinations authored by the authenticated vet role qualify.
    from sqlalchemy.orm import aliased

    successor = aliased(HealthEvent)
    examination = session.scalar(
        select(HealthEvent.event_date)
        .where(
            HealthEvent.species == code.species,
            HealthEvent.animal_id == code.animal_id,
            HealthEvent.kind == "examination",
            HealthEvent.actor_role == "veterinar",
            ~exists(select(successor.id).where(successor.correction_of == HealthEvent.id)),
        )
        .order_by(HealthEvent.event_date.desc())
        .limit(1)
    )
    # Deliberate public whitelist: never serialize owner, GPS, notes, actor, image or price.
    return {
        "animal_id": code.animal_id,
        "species": code.species.value,
        "slaughter_date": terminal.details["observed_at"][:10],
        "facility_id": terminal.details["facility_id"],
        "last_veterinary_examination_date": examination.isoformat() if examination else None,
    }
