from pathlib import Path

import yaml
from pydantic import Field, model_validator

from app.core.species import ConfigBase, Species


class SecurityConfig(ConfigBase):
    species: Species
    enabled: bool
    config_version: int = Field(ge=1)
    analysis_max_dimension: int = Field(ge=64, le=1024)
    periodic_peak_fraction: float = Field(gt=0, le=1)
    reflection_pixel_threshold: int = Field(ge=1, le=255)
    reflection_max_saturation: int = Field(ge=0, le=255)
    reflection_min_area_fraction: float = Field(gt=0, lt=1)
    rectangle_min_area_fraction: float = Field(gt=0, lt=1)
    rectangle_max_area_fraction: float = Field(gt=0, le=1)
    gps_max_accuracy_m: float = Field(gt=0)
    gps_max_age_seconds: float = Field(gt=0)
    gps_max_speed_mps: float = Field(gt=0)
    capture_max_age_seconds: float = Field(gt=0)
    future_tolerance_seconds: float = Field(ge=0)

    @model_validator(mode="after")
    def ordered_area(self):
        if self.rectangle_min_area_fraction >= self.rectangle_max_area_fraction:
            raise ValueError("Rectangle area bounds must be ordered")
        return self


def load_security_configs(directory: Path):
    configs = {}
    for species in Species:
        config = SecurityConfig.model_validate(
            yaml.safe_load((directory / f"{species.value}.yaml").read_text("utf-8"))
        )
        if config.species != species:
            raise ValueError("Security config species mismatch")
        configs[species] = config
    return configs
