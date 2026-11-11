from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.core.species import Species
from app.schemas.capture import GPS
from app.schemas.common import SafeTimestamp, StrictInput


class Owner(StrictInput):
    owner_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
    name: str = Field(min_length=1, max_length=120)

    @field_validator("name")
    @classmethod
    def visible_name(cls, value):
        value = value.strip()
        if not value or any(ord(char) < 32 for char in value):
            raise ValueError("A nonblank owner name without control characters is required")
        return value


class NumberedAnimal(StrictInput):
    species: Species
    owner: Owner


class RegistryObservation(StrictInput):
    expected_version: int = Field(ge=1)
    observed_at: SafeTimestamp
    gps: GPS | None = None
    reason: str = Field(min_length=1, max_length=1000)

    @field_validator("reason")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("A reason is required")
        return value.strip()


class OwnerChange(RegistryObservation):
    owner: Owner
    price_uzs: int | None = Field(default=None, ge=0, le=10**15, strict=True)
    currency: Literal["UZS"] | None = None

    @model_validator(mode="after")
    def price_currency(self):
        if (self.price_uzs is None) != (self.currency is None):
            raise ValueError("An optional whole-sum sale price requires UZS currency")
        return self


class Retirement(RegistryObservation):
    lifecycle: Literal["deceased", "slaughtered"]
    facility_id: str | None = Field(default=None, pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
    capture_id: UUID | None = None

    @model_validator(mode="after")
    def slaughter_facility(self):
        if self.lifecycle == "slaughtered" and self.facility_id is None:
            raise ValueError("Slaughter reports require a facility ID")
        if self.lifecycle == "deceased" and self.facility_id is not None:
            raise ValueError("A deceased report is not a slaughter facility record")
        return self


class RegistryAnimal(StrictInput):
    species: Species
    animal_id: str
    status: str
    version: int
    created_at: datetime
    registered_by: str | None
    lifecycle: Literal["active", "deceased", "slaughtered"]
    owner: Owner | None
    numbered_id: str | None
    retired_at: datetime | None
    can_manage: bool
    terminal_record: dict | None
