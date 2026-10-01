from datetime import UTC, datetime
from typing import Annotated, Literal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import AdminDep, PrincipalDep
from app.core.database import get_session
from app.core.species import Species
from app.models.business import Animal, AuditEvent, DuplicateCase
from app.models.capture import Capture
from app.schemas.business import (
    AnimalRegistration,
    AnimalResponse,
    DuplicateResponse,
    DuplicateReview,
    ManualFlag,
    StatusChange,
)
from app.schemas.capture import CaptureResponse
from app.services.registration import audit

router = APIRouter(prefix="/api/v1")
SessionDep = Annotated[Session, Depends(get_session)]


def enabled(request: Request, species: Species):
    if not request.app.state.species_configs[species].enabled:
        raise HTTPException(422, "This species is disabled")


@router.post("/animals", response_model=AnimalResponse, status_code=201)
def register(data: AnimalRegistration, request: Request, session: SessionDep, principal: PrincipalDep):
    enabled(request, data.species)
    record = Animal(
        species=data.species,
        animal_id=data.animal_id,
        status="open",
        version=1,
        created_at=datetime.now(UTC),
        registered_by=principal.operator_id,
    )
    session.add(record)
    audit(session, data.species, data.animal_id, principal.operator_id, "animal_registered", {})
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(409, "Species/animal ID already registered") from exc
    return record


@router.get("/animals", response_model=list[AnimalResponse])
def list_animals(
    session: SessionDep,
    principal: PrincipalDep,
    species: Species,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    return session.scalars(
        select(Animal).where(Animal.species == species).order_by(Animal.animal_id).limit(limit).offset(offset)
    ).all()


@router.get("/animals/{species}/{animal_id}", response_model=AnimalResponse)
def get_animal(species: Species, animal_id: str, session: SessionDep, principal: PrincipalDep):
    record = session.get(Animal, (species, animal_id))
    if record is None:
        raise HTTPException(404, "Animal registration not found")
    return record


@router.patch("/animals/{species}/{animal_id}/status", response_model=AnimalResponse)
def set_status(
    species: Species,
    animal_id: str,
    data: StatusChange,
    request: Request,
    session: SessionDep,
    admin: AdminDep,
):
    enabled(request, species)
    record = get_animal(species, animal_id, session, admin)
    before = record.status
    changed = session.execute(
        update(Animal)
        .where(
            Animal.species == species,
            Animal.animal_id == animal_id,
            Animal.version == data.expected_version,
        )
        .values(status=data.status.value, version=Animal.version + 1)
    )
    if not changed.rowcount:
        session.rollback()
        raise HTTPException(409, "Registration changed; reload its version")
    audit(
        session,
        species,
        animal_id,
        admin.operator_id,
        "status_changed",
        {"before": before, "after": data.status.value, "reason": data.reason},
    )
    session.commit()
    session.refresh(record)
    return record


@router.get("/captures/{capture_id}", response_model=CaptureResponse)
def get_capture(capture_id: UUID, session: SessionDep, principal: PrincipalDep):
    record = session.get(Capture, str(capture_id))
    if record is None or (principal.role != "admin" and record.operator_id != principal.operator_id):
        raise HTTPException(404, "Capture not found")
    return record


@router.get("/admin/duplicates", response_model=list[DuplicateResponse])
def list_duplicates(
    session: SessionDep,
    admin: AdminDep,
    species: Species,
    state: Literal["pending", "confirmed", "dismissed"] = "pending",
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    return session.scalars(
        select(DuplicateCase)
        .where(
            DuplicateCase.species == species,
            DuplicateCase.state == state,
        )
        .order_by(DuplicateCase.created_at, DuplicateCase.id)
        .limit(limit)
        .offset(offset)
    ).all()


@router.post("/admin/duplicates", response_model=DuplicateResponse, status_code=201)
def manual_flag(data: ManualFlag, session: SessionDep, admin: AdminDep):
    record = get_capture(data.capture_id, session, admin)
    case = DuplicateCase(
        id=str(uuid4()),
        species=record.species,
        animal_id=record.animal_id,
        capture_id=record.id,
        reason="manual_review",
        state="pending",
        version=1,
        created_at=datetime.now(UTC),
        review_note=data.note,
    )
    session.add(case)
    audit(
        session,
        record.species,
        record.animal_id,
        admin.operator_id,
        "duplicate_flagged",
        {"case_id": case.id, "note": data.note},
    )
    session.commit()
    return case


@router.patch("/admin/duplicates/{case_id}", response_model=DuplicateResponse)
def review_duplicate(case_id: UUID, data: DuplicateReview, session: SessionDep, admin: AdminDep):
    record = session.get(DuplicateCase, str(case_id))
    if record is None:
        raise HTTPException(404, "Duplicate case not found")
    before = record.state
    changed = session.execute(
        update(DuplicateCase)
        .where(
            DuplicateCase.id == str(case_id),
            DuplicateCase.version == data.expected_version,
        )
        .values(
            state=data.state,
            version=DuplicateCase.version + 1,
            reviewed_at=datetime.now(UTC),
            reviewed_by=admin.operator_id,
            review_note=data.note,
        )
    )
    if not changed.rowcount:
        session.rollback()
        raise HTTPException(409, "Duplicate review changed; reload its version")
    audit(
        session,
        record.species,
        record.animal_id,
        admin.operator_id,
        "duplicate_reviewed",
        {"case_id": record.id, "before": before, "after": data.state, "note": data.note},
    )
    session.commit()
    session.refresh(record)
    return record


@router.get("/admin/audit")
def list_audit(
    session: SessionDep,
    admin: AdminDep,
    species: Species,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    records = session.scalars(
        select(AuditEvent)
        .where(AuditEvent.species == species)
        .order_by(AuditEvent.received_at, AuditEvent.id)
        .limit(limit)
        .offset(offset)
    ).all()
    return [
        {
            "id": r.id,
            "species": r.species,
            "animal_id": r.animal_id,
            "action": r.action,
            "actor_id": r.actor_id,
            "received_at": r.received_at,
            "details": r.details,
        }
        for r in records
    ]
