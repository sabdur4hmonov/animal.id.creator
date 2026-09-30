from datetime import datetime
from typing import Literal

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, field_validator

from app.core.species import Species


class GPS(BaseModel):
    model_config = ConfigDict(extra="forbid")
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class CaptureMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")
    animal_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
    species: Species
    gps: GPS | None = None
    timestamp: AwareDatetime
    operator_id: str = Field(min_length=1, max_length=100)

    @field_validator("animal_id")
    @classmethod
    def safe_directory(cls, value: str) -> str:
        reserved = {"CON", "PRN", "AUX", "NUL"}
        reserved |= {f"{prefix}{i}" for prefix in ("COM", "LPT") for i in range(1, 10)}
        if value.upper() in reserved:
            raise ValueError("Reserved filesystem name")
        return value

    @field_validator("operator_id")
    @classmethod
    def nonblank_operator(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Operator ID cannot be blank")
        return value.strip()


class QualityResult(BaseModel):
    passed: bool
    score: float = Field(ge=0, le=1)
    blur_variance: float
    brightness: float
    dark_fraction: float
    bright_fraction: float
    width: int
    height: int
    reasons: list[str]


class CaptureResponse(BaseModel):
    id: str
    animal_id: str
    species: Species
    gps: GPS | None
    timestamp: datetime
    operator_id: str
    image_quality_score: float
    file_path: str
    crop_path: str | None
    crop_status: Literal["pending_model", "cropped"]
    quality: QualityResult
    crop_quality: QualityResult | None
    detection: dict | None
    config_version: int
