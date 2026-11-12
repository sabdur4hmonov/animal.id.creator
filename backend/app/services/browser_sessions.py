"""Opaque browser cookies; authoritative API credentials are checked on every request."""

import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select

from app.models.accounts import UserAccount
from app.models.portal import BrowserSession
from app.services.registry import utc

COOKIE = "__Host-chorvam"


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def new_session(session, principal, settings):
    token = secrets.token_urlsafe(32)
    now = datetime.now(UTC)
    row = BrowserSession(
        token_sha256=digest(token),
        credential_sha256=principal.token_sha256,
        operator_id=principal.operator_id,
        csrf=secrets.token_urlsafe(32),
        created_at=now,
        expires_at=now + timedelta(seconds=settings.browser_session_seconds),
    )
    session.add(row)
    session.commit()
    return token, row


def browser_principal(request, session):
    token = request.cookies.get(COOKIE, "")
    if not token or len(token) > 128:
        return None
    row = session.get(BrowserSession, digest(token))
    if row is None or row.revoked_at or utc(row.expires_at) <= datetime.now(UTC):
        return None
    principal = next(
        (
            p
            for p in request.app.state.credentials
            if p.operator_id == row.operator_id and hmac.compare_digest(p.token_sha256, row.credential_sha256)
        ),
        None,
    )
    if principal is None:
        account = session.scalar(select(UserAccount).where(UserAccount.operator_id == row.operator_id))
        if (
            account is None
            or account.disabled_at
            or not hmac.compare_digest(digest(account.password_hash), row.credential_sha256)
        ):
            return None
        from app.core.auth import Principal

        principal = Principal(
            operator_id=account.operator_id, role=account.role, token_sha256=row.credential_sha256
        )
    if request.method not in ("GET", "HEAD", "OPTIONS") and not hmac.compare_digest(
        request.headers.get("X-CSRF-Token", ""), row.csrf
    ):
        raise HTTPException(403, "CSRF token required")
    request.state.browser_session = row
    return principal


def set_cookie(response, token, seconds):
    response.set_cookie(
        COOKIE, token, max_age=seconds, secure=True, httponly=True, samesite="strict", path="/"
    )
