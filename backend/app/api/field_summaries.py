from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import select

from app.api.business import SessionDep, enabled
from app.api.registry import RequestKey
from app.core.auth import PrincipalDep
from app.core.species import Species
from app.models.portal import FieldSummary
from app.schemas.portal import SummaryInput
from app.services.idempotency import lock_request
from app.services.registration import audit
from app.services.registry import require_record, run_operation

router = APIRouter(prefix="/api/v1/registry/animals/{species}/{animal_id}/field-summaries")


@router.post("", status_code=201)
def add_summary(
    species: Species,
    animal_id: str,
    data: SummaryInput,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    key: RequestKey,
):
    enabled(request, species)
    animal = require_record(session, species, animal_id)
    if principal.role != "admin" and (
        principal.role != "operator" or animal.registered_by != principal.operator_id
    ):
        raise HTTPException(403, "Registering operator or administrator required")

    def create():
        lock_request(session, "field_summary:" + principal.operator_id, data.local_event_key)
        if session.scalar(
            select(FieldSummary.id).where(
                FieldSummary.actor_id == principal.operator_id,
                FieldSummary.local_event_key == data.local_event_key,
            )
        ):
            raise HTTPException(409, "Summary already recorded; retry the original request key")
        row = FieldSummary(
            id=str(uuid4()),
            species=species,
            animal_id=animal_id,
            actor_id=principal.operator_id,
            local_event_key=data.local_event_key,
            observed_at=data.observed_at,
            received_at=datetime.now(UTC),
            payload=data.model_dump(
                mode="json", exclude={"local_event_key", "observed_at"}, exclude_none=True
            ),
        )
        session.add(row)
        audit(
            session,
            species,
            animal_id,
            principal.operator_id,
            "field_summary_recorded",
            {"summary_id": row.id},
        )
        session.flush()
        return {
            "id": row.id,
            "local_event_key": row.local_event_key,
            "species": species.value,
            "animal_id": animal_id,
        }

    return run_operation(session, principal, key, f"field_summary:{species.value}:{animal_id}", data, create)
