import hashlib
import json
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.models.business import Animal, AuditEvent
from app.models.capture import Capture
from app.models.registry import AnimalNumberCounter, AnimalProfile, RegistryReceipt
from app.schemas.registry import RegistryAnimal
from app.services.idempotency import lock_request
from app.services.numbering import capacity, format_number
from app.services.registration import audit


def utc(value):
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def registry_view(session, record, principal):
    profile = session.get(AnimalProfile, (record.species, record.animal_id))
    terminal = session.scalar(
        select(AuditEvent).where(
            AuditEvent.species == record.species,
            AuditEvent.animal_id == record.animal_id,
            AuditEvent.action.in_(["animal_deceased", "animal_slaughtered"]),
        )
    )
    result = RegistryAnimal(
        species=record.species,
        animal_id=record.animal_id,
        status=record.status,
        version=record.version,
        created_at=utc(record.created_at),
        registered_by=record.registered_by,
        lifecycle=profile.lifecycle if profile else "active",
        owner=profile.owner if profile else None,
        numbered_id=profile.numbered_id if profile else None,
        retired_at=utc(profile.retired_at) if profile and profile.retired_at else None,
        can_manage=principal.role == "admin" or record.registered_by == principal.operator_id,
        terminal_record=None
        if terminal is None
        else {
            "event_id": terminal.id,
            "actor_id": terminal.actor_id,
            "received_at": utc(terminal.received_at).isoformat(),
            **terminal.details,
        },
    )
    return result.model_dump(mode="json")


def require_record(session, species, animal_id):
    record = session.get(Animal, (species, animal_id))
    if record is None:
        raise HTTPException(404, "Animal registration not found")
    return record


def run_operation(session, principal, key, operation, data, execute):
    body = data.model_dump(mode="json")
    if hasattr(data, "observed_at"):
        body["observed_at"] = utc(data.observed_at).isoformat()
    digest = hashlib.sha256(
        json.dumps(
            {"operation": operation, "body": body}, sort_keys=True, separators=(",", ":"), allow_nan=False
        ).encode()
    ).hexdigest()
    lock_request(session, "registry:" + principal.operator_id, key)
    previous = session.get(RegistryReceipt, (principal.operator_id, key))
    if previous is not None:
        if previous.payload_sha256 != digest:
            raise HTTPException(409, "Registry request key was used with a different operation or payload")
        return previous.response
    response = execute()
    session.add(
        RegistryReceipt(
            operator_id=principal.operator_id, request_key=key, payload_sha256=digest, response=response
        )
    )
    session.flush()
    session.commit()
    return response


def next_id(session, config):
    insert = pg_insert if session.get_bind().dialect.name == "postgresql" else sqlite_insert
    prefix = config.numbering.prefix
    while True:
        number = session.scalar(
            insert(AnimalNumberCounter)
            .values(prefix=prefix, last_number=1)
            .on_conflict_do_update(
                index_elements=["prefix"],
                set_={"last_number": AnimalNumberCounter.last_number + 1},
                where=AnimalNumberCounter.last_number < capacity(config.numbering),
            )
            .returning(AnimalNumberCounter.last_number)
        )
        if number is None:
            raise HTTPException(503, "Animal numbering range is exhausted; never reset its counter")
        candidate = format_number(config.numbering, number)
        # Preserve legacy spelling and skip all look-alike IDs across species.
        if (
            session.scalar(select(Animal.animal_id).where(func.upper(Animal.animal_id) == candidate).limit(1))
            is None
        ):
            return candidate


def issue_animal(session, config, data, principal):
    animal_id = next_id(session, config)
    record = Animal(
        species=data.species,
        animal_id=animal_id,
        status="open",
        version=1,
        created_at=datetime.now(UTC),
        registered_by=principal.operator_id,
    )
    session.add(record)
    session.flush()
    session.add(
        AnimalProfile(
            species=data.species,
            animal_id=animal_id,
            numbered_id=animal_id,
            lifecycle="active",
            owner=data.owner.model_dump(mode="json"),
        )
    )
    audit(
        session,
        data.species,
        animal_id,
        principal.operator_id,
        "animal_number_issued",
        {"owner": data.owner.model_dump(mode="json"), "numbering": config.numbering.model_dump()},
    )
    session.flush()
    return registry_view(session, record, principal)


def prepare_change(session, record, data, principal):
    if principal.role != "admin" and record.registered_by != principal.operator_id:
        raise HTTPException(403, "Only the registering operator or an administrator can change this animal")
    if utc(data.observed_at) > datetime.now(UTC) + timedelta(minutes=5):
        raise HTTPException(422, "Reported event time cannot be in the future")
    changed = session.execute(
        update(Animal)
        .where(
            Animal.species == record.species,
            Animal.animal_id == record.animal_id,
            Animal.version == data.expected_version,
        )
        .values(version=Animal.version + 1)
    )
    if not changed.rowcount:
        raise HTTPException(409, "Animal changed; reload before submitting another operation")
    # The successful version UPDATE locks the animal before reading its projection.
    # This prevents racing a retirement with a guessed future version/owner edit.
    profile = session.get(AnimalProfile, (record.species, record.animal_id), populate_existing=True)
    if profile and profile.lifecycle != "active":
        raise HTTPException(
            409, "Animal is archived; its ID, owner and terminal record cannot be reused or edited"
        )
    if profile is None:
        profile = AnimalProfile(species=record.species, animal_id=record.animal_id, lifecycle="active")
        session.add(profile)
    return profile


def change_owner(session, record, data, principal):
    profile = prepare_change(session, record, data, principal)
    previous = profile.owner
    owner = data.owner.model_dump(mode="json")
    if previous is not None and previous["owner_id"] == owner["owner_id"]:
        raise HTTPException(409, "This owner is already recorded; no transfer applied")
    profile.owner = owner
    audit(
        session,
        record.species,
        record.animal_id,
        principal.operator_id,
        "owner_changed",
        {
            "before": previous,
            "after": owner,
            "observed_at": utc(data.observed_at).isoformat(),
            "gps": data.gps.model_dump() if data.gps else None,
            "reason": data.reason,
        },
    )
    session.flush()
    session.refresh(record)
    return registry_view(session, record, principal)


def retire_animal(session, record, data, principal):
    profile = prepare_change(session, record, data, principal)
    capture = None
    if data.capture_id is not None:
        capture = session.get(Capture, str(data.capture_id))
        if capture is None or (capture.species, capture.animal_id) != (record.species, record.animal_id):
            raise HTTPException(422, "Referenced capture must belong to this species/animal ID")
        if principal.role != "admin" and capture.operator_id != principal.operator_id:
            raise HTTPException(403, "Cannot attach another operator's capture")
    profile.lifecycle = data.lifecycle
    profile.retired_at = datetime.now(UTC)
    audit(
        session,
        record.species,
        record.animal_id,
        principal.operator_id,
        "animal_" + data.lifecycle,
        {
            "lifecycle": data.lifecycle,
            "owner_at_recording": profile.owner,
            "observed_at": utc(data.observed_at).isoformat(),
            "gps": data.gps.model_dump() if data.gps else None,
            "reason": data.reason,
            "facility_id": data.facility_id,
            "capture_id": str(data.capture_id) if data.capture_id else None,
            "capture_stored_sha256": capture.stored_sha256 if capture else None,
            "verification_level": "authenticated_operator_report",
            "biometric_identity_verified": False,
            "independent_slaughter_verified": False,
        },
    )
    session.flush()
    session.refresh(record)
    return registry_view(session, record, principal)
