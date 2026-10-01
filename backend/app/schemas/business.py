from datetime import datetime
from enum import Enum
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.species import Species
from app.schemas.capture import CaptureMetadata
from app.schemas.common import StrictInput


class AnimalStatus(str, Enum):
    open = "open"
    insured = "insured"
    collateral = "collateral"


class AnimalRegistration(StrictInput):
    species: Species
    animal_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")

    @field_validator("animal_id")
    @classmethod
    def safe_id(cls, value):
        return CaptureMetadata.safe_directory(value)


class StatusChange(StrictInput):
    status: AnimalStatus
    expected_version: int = Field(ge=1)
    reason: str = Field(min_length=1, max_length=1000)

    @field_validator("reason")
    @classmethod
    def nonblank_reason(cls, value):
        if not value.strip():
            raise ValueError("A review reason is required")
        return value.strip()


class DuplicateReview(StrictInput):
    state: Literal["pending", "confirmed", "dismissed"]
    expected_version: int = Field(ge=1)
    note: str = Field(min_length=1, max_length=1000)

    @field_validator("note")
    @classmethod
    def nonblank_note(cls, value):
        return StatusChange.nonblank_reason(value)


class ManualFlag(StrictInput):
    capture_id: UUID
    note: str = Field(min_length=1, max_length=1000)

    @field_validator("note")
    @classmethod
    def nonblank_note(cls, value):
        return StatusChange.nonblank_reason(value)


class AnimalResponse(BaseModel):
    species: Species
    animal_id: str
    status: AnimalStatus
    version: int
    created_at: datetime
    registered_by: str | None


class DuplicateResponse(BaseModel):
    id: str
    species: Species
    animal_id: str
    capture_id: str
    matched_capture_id: str | None
    reason: str
    state: str
    version: int
    created_at: datetime
    reviewed_at: datetime | None
    reviewed_by: str | None
    review_note: str | None
