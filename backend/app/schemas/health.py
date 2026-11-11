from datetime import UTC, date, datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator

from app.schemas.common import StrictInput


class HealthInput(StrictInput):
    local_event_key: str = Field(pattern=r"^[a-f0-9]{32}$")
    kind: Literal["vaccination", "treatment", "illness", "examination"]
    event_date: date
    description: str = Field(min_length=1, max_length=500)
    veterinarian_name: str | None = Field(default=None, max_length=120)
    notes: str = Field(default="", max_length=1000)
    correction_of: UUID | None = None

    @field_validator("event_date")
    @classmethod
    def past_date(cls, value):
        if value > datetime.now(UTC).date():
            raise ValueError("Future health dates are not accepted")
        return value

    @field_validator("description", "veterinarian_name", "notes")
    @classmethod
    def clean_text(cls, value, info):
        if value is None:
            return None
        value = value.strip()
        if (info.field_name == "description" and not value) or any(
            ord(c) < 32 and c not in "\n\t" for c in value
        ):
            raise ValueError("Visible text is required")
        return value
