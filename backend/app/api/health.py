from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import select

from app.api.business import SessionDep, enabled
from app.api.registry import RequestKey
from app.core.auth import PrincipalDep
from app.core.roles import require_role
from app.core.species import Species
from app.models.health import HealthEvent
from app.schemas.health import HealthInput
from app.services.idempotency import lock_request
from app.services.registration import audit
from app.services.registry import require_record, run_operation, utc

router = APIRouter(prefix="/api/v1/registry/animals/{species}/{animal_id}/health")


def health_access(session, species, animal_id, principal, write=False):
    animal = require_record(session, species, animal_id)
    if write:
        require_role(principal, "admin", "operator", "veterinar")
    if principal.role == "operator" and animal.registered_by != principal.operator_id:
        raise HTTPException(403, "Health history requires access to this animal")
    return animal


def health_view(event):
    return {
        "id": event.id,
        "species": event.species.value,
        "animal_id": event.animal_id,
        "local_event_key": event.local_event_key,
        "kind": event.kind,
        "event_date": event.event_date.isoformat(),
        "description": event.description,
        "veterinarian_name": event.veterinarian_name,
        "notes": event.notes,
        "correction_of": event.correction_of,
        "actor_id": event.actor_id,
        "actor_role": event.actor_role,
        "received_at": utc(event.received_at).isoformat(),
        "verified_by_veterinarian": event.actor_role == "veterinar",
    }


@router.get("")
def history(species: Species, animal_id: str, request: Request, session: SessionDep, principal: PrincipalDep):
    enabled(request, species)
    health_access(session, species, animal_id, principal)
    events = session.scalars(
        select(HealthEvent)
        .where(HealthEvent.species == species, HealthEvent.animal_id == animal_id)
        .order_by(HealthEvent.event_date.desc(), HealthEvent.received_at.desc())
    )
    return [health_view(event) for event in events]


@router.post("", status_code=201)
def add_event(
    species: Species,
    animal_id: str,
    data: HealthInput,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    key: RequestKey,
):
    enabled(request, species)
    health_access(session, species, animal_id, principal, write=True)

    def create():
        limits = request.app.state.business_configs[species].health_history
        if limits and any(
            len(value or "") > maximum
            for value, maximum in (
                (data.description, limits.description_max_length),
                (data.veterinarian_name, limits.veterinarian_max_length),
                (data.notes, limits.notes_max_length),
            )
        ):
            raise HTTPException(422, "Health text exceeds configured limit")
        lock_request(session, f"health:{species.value}", animal_id)
        if session.scalar(
            select(HealthEvent.id).where(
                HealthEvent.actor_id == principal.operator_id,
                HealthEvent.local_event_key == data.local_event_key,
            )
        ):
            raise HTTPException(409, "This local event already exists; retry its original request key")
        if data.correction_of:
            target = session.get(HealthEvent, str(data.correction_of))
            if target is None or (target.species, target.animal_id) != (species, animal_id):
                raise HTTPException(422, "Correction must reference this animal's health event")
            if target.actor_role == "veterinar" and principal.role == "operator":
                raise HTTPException(
                    403, "Only a veterinarian or administrator may correct a veterinarian record"
                )
            if session.scalar(select(HealthEvent.id).where(HealthEvent.correction_of == target.id)):
                raise HTTPException(409, "Correct the latest revision, not an older event")
        event = HealthEvent(
            id=str(uuid4()),
            species=species,
            animal_id=animal_id,
            **data.model_dump(exclude={"correction_of"}),
            correction_of=str(data.correction_of) if data.correction_of else None,
            actor_id=principal.operator_id,
            actor_role=principal.role,
            received_at=datetime.now(UTC),
        )
        session.add(event)
        audit(
            session,
            species,
            animal_id,
            principal.operator_id,
            "health_recorded",
            {
                "health_event_id": event.id,
                "kind": event.kind,
                "correction_of": event.correction_of,
                "actor_role": principal.role,
            },
        )
        session.flush()
        return health_view(event)

    return run_operation(session, principal, key, f"health:{species.value}:{animal_id}", data, create)
