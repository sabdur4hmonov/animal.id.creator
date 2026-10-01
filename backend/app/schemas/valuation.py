from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import AwareDatetime, Field, field_validator, model_validator

from app.core.species import Species
from app.schemas.common import StrictInput


class Point3D(StrictInput):
    x: float = Field(ge=-10000, le=10000)
    y: float = Field(ge=-10000, le=10000)
    z: float = Field(ge=-10000, le=10000)
    confidence: float = Field(ge=0, le=1)


class KeypointMeasurements(StrictInput):
    # Points share a calibrated 3D coordinate frame; never infer girth from a side view.
    coordinate_system: Literal["calibrated_3d"]
    reference_start: Point3D
    reference_end: Point3D
    reference_length_cm: Decimal = Field(gt=0, le=1000)
    body_start: Point3D
    body_end: Point3D
    chest_contour: list[Point3D] = Field(min_length=4, max_length=200)


class ValuationRequest(StrictInput):
    species: Species
    method: Literal["schoorl", "trukhanovsky"]
    adult: Literal[True]  # Implemented formula convention is for adult cattle.
    breed_category: str | None = Field(default=None, min_length=1, max_length=32)
    chest_girth_cm: Decimal | None = Field(default=None, gt=0, le=500)
    body_length_cm: Decimal | None = Field(default=None, gt=0, le=500)
    keypoints: KeypointMeasurements | None = None
    currency: str = Field(pattern=r"^[A-Z]{3}$")

    @model_validator(mode="after")
    def measurement_source(self):
        if self.keypoints is not None:
            if self.chest_girth_cm is not None or self.body_length_cm is not None:
                raise ValueError("Choose tape measurements or calibrated 3D keypoints")
        elif self.chest_girth_cm is None or (self.method == "trukhanovsky" and self.body_length_cm is None):
            raise ValueError(
                "The selected formula needs chest girth and, for Trukhanovsky, straight body length"
            )
        return self


class MarketRateInput(StrictInput):
    species: Species
    currency: str = Field(pattern=r"^[A-Z]{3}$")
    basis: Literal["carcass"]
    price_per_kg: Decimal = Field(gt=0, le=1_000_000_000, max_digits=18, decimal_places=4)
    observed_at: AwareDatetime
    source: str = Field(min_length=1, max_length=500)
    expected_latest_id: UUID | None = None

    @field_validator("source")
    @classmethod
    def source_nonblank(cls, value):
        if not value.strip():
            raise ValueError("Price source cannot be blank")
        return value.strip()
