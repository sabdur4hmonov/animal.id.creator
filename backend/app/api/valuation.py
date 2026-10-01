from datetime import UTC, datetime, timedelta
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.api.business import enabled
from app.core.auth import AdminDep, PrincipalDep
from app.core.database import get_session
from app.core.species import Species
from app.models.valuation import MarketRate
from app.schemas.valuation import MarketRateInput, ValuationRequest
from app.services.registration import audit
from app.services.valuation import value_estimate

router = APIRouter(prefix="/api/v1")
SessionDep = Annotated[Session, Depends(get_session)]


def rate_response(rate):
    return {
        "id": rate.id,
        "species": rate.species,
        "currency": rate.currency,
        "basis": rate.basis,
        "price_per_kg": str(rate.price_per_kg),
        "observed_at": rate.observed_at,
        "source": rate.source,
        "received_at": rate.received_at,
        "operator_id": rate.operator_id,
    }


def latest_rate(session, species, currency):
    return session.scalar(
        select(MarketRate)
        .where(MarketRate.species == species, MarketRate.currency == currency)
        .order_by(MarketRate.received_at.desc(), MarketRate.id.desc())
        .limit(1)
    )


@router.post("/admin/market-rates", status_code=201)
def add_rate(data: MarketRateInput, request: Request, session: SessionDep, admin: AdminDep):
    enabled(request, data.species)
    if not request.app.state.business_configs[data.species].enabled:
        raise HTTPException(422, "Species valuation is disabled")
    now = datetime.now(UTC)
    if data.observed_at > now + timedelta(minutes=5):
        raise HTTPException(422, "Price observation cannot be in the future")
    if session.get_bind().dialect.name == "postgresql":
        session.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
            {"key": f"market:{data.species.value}:{data.currency}"},
        )
    previous = latest_rate(session, data.species, data.currency)
    if (str(data.expected_latest_id) if data.expected_latest_id else None) != (
        previous.id if previous else None
    ):
        raise HTTPException(409, "Market rate changed; supply the current rate ID")
    record = MarketRate(
        id=str(uuid4()),
        species=data.species,
        currency=data.currency,
        basis=data.basis,
        price_per_kg=data.price_per_kg,
        observed_at=data.observed_at.astimezone(UTC),
        source=data.source,
        received_at=now,
        operator_id=admin.operator_id,
    )
    session.add(record)
    audit(
        session,
        data.species,
        "MARKET",
        admin.operator_id,
        "market_rate_added",
        {
            "rate_id": record.id,
            "previous_id": previous.id if previous else None,
            "currency": data.currency,
            "price_per_kg": str(data.price_per_kg),
            "source": data.source,
        },
    )
    session.commit()
    return rate_response(record)


@router.get("/market-rates/{species}")
def get_rate(
    species: Species,
    session: SessionDep,
    principal: PrincipalDep,
    currency: Annotated[str, Query(pattern=r"^[A-Z]{3}$")],
):
    rate = latest_rate(session, species, currency)
    if rate is None:
        raise HTTPException(404, "No market rate configured for this species/currency")
    return rate_response(rate)


@router.post("/valuation")
def calculate(data: ValuationRequest, request: Request, session: SessionDep, principal: PrincipalDep):
    enabled(request, data.species)
    config = request.app.state.business_configs[data.species]
    if not config.enabled:
        raise HTTPException(422, "Species valuation is disabled")
    rate = latest_rate(session, data.species, data.currency)
    if rate is None:
        raise HTTPException(409, "Set an administrator market rate for this species/currency first")
    try:
        return value_estimate(data, config, rate)
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
