from typing import Annotated, Literal

from fastapi import APIRouter, Header, HTTPException, Query, Request
from sqlalchemy import func, select

from app.api.business import SessionDep, enabled
from app.core.auth import PrincipalDep
from app.core.species import Species
from app.models.business import Animal, AuditEvent
from app.models.registry import AnimalProfile
from app.schemas.registry import NumberedAnimal, OwnerChange, RegistryAnimal, Retirement
from app.services.registry import (
    change_owner,
    issue_animal,
    registry_detail,
    registry_query,
    render_registry,
    require_record,
    retire_animal,
    run_operation,
    utc,
)

router = APIRouter(prefix="/api/v1/registry")
RequestKey = Annotated[str, Header(alias="Idempotency-Key", pattern=r"^[A-Za-z0-9_-]{16,128}$")]


@router.post("/animals", response_model=RegistryAnimal, status_code=201)
def issue(
    data: NumberedAnimal, request: Request, session: SessionDep, principal: PrincipalDep, key: RequestKey
):
    enabled(request, data.species)
    return run_operation(
        session,
        principal,
        key,
        "issue",
        data,
        lambda: issue_animal(session, request.app.state.species_configs[data.species], data, principal),
    )


@router.get("/animals", response_model=list[RegistryAnimal])
def list_records(
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    species: Species,
    lifecycle: Literal["active", "deceased", "slaughtered", "all"] = "active",
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    enabled(request, species)
    query = registry_query().where(Animal.species == species)
    if lifecycle != "all":
        query = query.where(func.coalesce(AnimalProfile.lifecycle, "active") == lifecycle)
    records = session.execute(
        query.order_by(Animal.created_at.desc(), Animal.animal_id).limit(limit).offset(offset)
    ).all()
    return [render_registry(*snapshot, principal) for snapshot in records]


@router.get("/animals/{species}/{animal_id}", response_model=RegistryAnimal)
def detail(species: Species, animal_id: str, request: Request, session: SessionDep, principal: PrincipalDep):
    enabled(request, species)
    return registry_detail(session, species, animal_id, principal)


@router.post("/animals/{species}/{animal_id}/owner", response_model=RegistryAnimal)
def owner(
    species: Species,
    animal_id: str,
    data: OwnerChange,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    key: RequestKey,
):
    enabled(request, species)

    def apply_owner():
        limits = request.app.state.business_configs[species].ownership_history
        if limits and data.price_uzs is not None and data.price_uzs > limits.max_price_uzs:
            raise HTTPException(422, "Sale price exceeds configured limit")
        return change_owner(session, require_record(session, species, animal_id), data, principal)

    return run_operation(
        session,
        principal,
        key,
        f"owner:{species.value}:{animal_id}",
        data,
        apply_owner,
    )


@router.post("/animals/{species}/{animal_id}/retirement", response_model=RegistryAnimal)
def retire(
    species: Species,
    animal_id: str,
    data: Retirement,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    key: RequestKey,
):
    enabled(request, species)
    return run_operation(
        session,
        principal,
        key,
        f"retire:{species.value}:{animal_id}",
        data,
        lambda: retire_animal(session, require_record(session, species, animal_id), data, principal),
    )


@router.get("/animals/{species}/{animal_id}/history")
def history(
    species: Species,
    animal_id: str,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    enabled(request, species)
    require_record(session, species, animal_id)
    events = session.scalars(
        select(AuditEvent)
        .where(AuditEvent.species == species, AuditEvent.animal_id == animal_id)
        .order_by(AuditEvent.received_at.desc(), AuditEvent.id)
        .limit(limit)
        .offset(offset)
    ).all()
    return [
        {
            "id": event.id,
            "action": event.action,
            "actor_id": event.actor_id,
            "received_at": utc(event.received_at).isoformat(),
            "details": event.details,
        }
        for event in events
    ]


@router.get("/animals/{species}/{animal_id}/slaughter-check")
def slaughter_check(
    species: Species, animal_id: str, request: Request, session: SessionDep, principal: PrincipalDep
):
    animal = detail(species, animal_id, request, session, principal)
    return {
        "animal": animal,
        "recorded_slaughter": animal["lifecycle"] == "slaughtered"
        and animal["terminal_record"] is not None
        and animal["terminal_record"].get("lifecycle") == "slaughtered",
        "verification_level": "registry_record_only",
        "biometric_identity_verified": False,
        "independent_slaughter_verified": False,
    }
