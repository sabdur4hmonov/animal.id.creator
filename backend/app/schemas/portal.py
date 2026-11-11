from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Literal

from pydantic import Field, model_validator

from app.schemas.common import SafeTimestamp, StrictInput


class WeightSummary(StrictInput):
    mode: Literal["fast", "contour", "snapshot"]
    trukhanovsky_kg: Decimal = Field(gt=0, le=10000, max_digits=12, decimal_places=6)
    schoorl_kg: Decimal = Field(gt=0, le=10000, max_digits=12, decimal_places=6)
    config_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    source_key: str = Field(pattern=r"^[a-f0-9]{32}$")
    approximate: Literal[True] = True


class SummaryInput(StrictInput):
    local_event_key: str = Field(pattern=r"^[a-f0-9]{32}$")
    observed_at: SafeTimestamp
    tag: str | None = Field(default=None, min_length=1, max_length=120)
    weight: WeightSummary | None = None
    scale_kg: Decimal | None = Field(default=None, gt=0, le=10000, max_digits=12, decimal_places=6)

    @model_validator(mode="after")
    def exactly_one(self):
        if sum(x is not None for x in (self.tag, self.weight, self.scale_kg)) != 1:
            raise ValueError("Exactly one tag, estimated weight or reported scale weight is required")
        if self.tag is not None and (not self.tag.strip() or any(ord(c) < 32 for c in self.tag)):
            raise ValueError("A visible tag without control characters is required")
        if self.observed_at > datetime.now(UTC) + timedelta(minutes=5):
            raise ValueError("Observation cannot be in the future")
        return self
