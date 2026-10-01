from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.models.business import Animal, AuditEvent, DuplicateCase
from app.models.capture import Capture


def audit(session: Session, species, animal_id, actor_id, action, details):
    session.add(
        AuditEvent(
            id=str(uuid4()),
            species=species,
            animal_id=animal_id,
            actor_id=actor_id,
            action=action,
            received_at=datetime.now(UTC),
            details=details,
        )
    )


def ensure_animal(session: Session, metadata) -> None:
    # Unique composite key and conflict-safe insert handle simultaneous first scans.
    dialect = session.get_bind().dialect.name
    insert = pg_insert if dialect == "postgresql" else sqlite_insert
    statement = (
        insert(Animal)
        .values(
            species=metadata.species,
            animal_id=metadata.animal_id,
            status="open",
            version=1,
            created_at=datetime.now(UTC),
            registered_by=metadata.operator_id,
        )
        .on_conflict_do_nothing(index_elements=["species", "animal_id"])
    )
    if session.execute(statement).rowcount:
        audit(
            session,
            metadata.species,
            metadata.animal_id,
            metadata.operator_id,
            "animal_registered_from_scan",
            {},
        )


def duplicate_candidates(session: Session, species, fingerprint: str):
    if session.get_bind().dialect.name == "postgresql":
        # Serialize the same fingerprint across API workers without blocking other images.
        lock = int.from_bytes(bytes.fromhex(fingerprint[:16]), "big", signed=True)
        session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock})
    return session.scalars(
        select(Capture)
        .where(
            Capture.species == species,
            Capture.pixel_sha256 == fingerprint,
        )
        .order_by(Capture.id)
        .limit(101)
    ).all()


def flag_duplicates(session: Session, record: Capture, matches):
    for previous in matches[:100]:
        case = DuplicateCase(
            id=str(uuid4()),
            species=record.species,
            animal_id=record.animal_id,
            capture_id=record.id,
            matched_capture_id=previous.id,
            reason="exact_image_reuse",
            state="pending",
            version=1,
            created_at=datetime.now(UTC),
        )
        session.add(case)
        audit(
            session,
            record.species,
            record.animal_id,
            record.operator_id,
            "duplicate_flagged",
            {"case_id": case.id, "matched_capture_id": previous.id},
        )
