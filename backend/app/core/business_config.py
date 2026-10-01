from decimal import Decimal
from pathlib import Path

import yaml
from pydantic import Field, model_validator

from app.core.species import ConfigBase, Species


class WeightConfig(ConfigBase):
    schoorl_offset_cm: Decimal = Field(ge=0, le=100)
    denominator: Decimal = Field(gt=0, le=10000)
    trukhanovsky_factors: dict[str, Decimal]
    carcass_yield_min: Decimal = Field(gt=0, le=1)
    carcass_yield_max: Decimal = Field(gt=0, le=1)
    min_keypoint_confidence: float = Field(gt=0, le=1)

    @model_validator(mode="after")
    def valid_ranges(self):
        if self.carcass_yield_min > self.carcass_yield_max:
            raise ValueError("Carcass yield bounds must be ordered")
        if any(not value.is_finite() or not 0 < value <= 10 for value in self.trukhanovsky_factors.values()):
            raise ValueError("Invalid Trukhanovsky factors")
        return self


class BusinessConfig(ConfigBase):
    species: Species
    enabled: bool
    config_version: int = Field(ge=1)
    weight: WeightConfig


def load_business_configs(directory: Path):
    result = {}
    for species in Species:
        config = BusinessConfig.model_validate(
            yaml.safe_load((directory / f"{species.value}.yaml").read_text("utf-8"))
        )
        if config.species != species:
            raise ValueError("Business config species mismatch")
        result[species] = config
    return result
