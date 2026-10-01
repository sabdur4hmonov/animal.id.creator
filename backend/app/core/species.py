from enum import Enum
from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator


class Species(str, Enum):
    cattle = "cattle"
    sheep = "sheep"


class ConfigBase(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)


class ModelConfig(ConfigBase):
    checkpoint: str
    class_name: str
    confidence: float = Field(gt=0, le=1)
    image_size: int = Field(gt=0)


class CropConfig(ConfigBase):
    padding_ratio: float = Field(ge=0, le=0.5)
    min_width: int = Field(gt=0)
    min_height: int = Field(gt=0)
    min_area_ratio: float = Field(gt=0, lt=1)
    edge_margin_ratio: float = Field(ge=0, lt=0.5)


class QualityConfig(ConfigBase):
    min_width: int = Field(gt=0)
    min_height: int = Field(gt=0)
    analysis_max_dimension: int = Field(ge=32)
    blur_min_variance: float = Field(gt=0)
    brightness_min: float = Field(ge=0, lt=255)
    brightness_max: float = Field(gt=0, le=255)
    dark_pixel_threshold: int = Field(ge=0, le=255)
    bright_pixel_threshold: int = Field(ge=0, le=255)
    max_dark_fraction: float = Field(gt=0, le=1)
    max_bright_fraction: float = Field(gt=0, le=1)

    @model_validator(mode="after")
    def ordered_thresholds(self):
        if self.brightness_min >= self.brightness_max:
            raise ValueError("brightness_min must be below brightness_max")
        if self.dark_pixel_threshold >= self.bright_pixel_threshold:
            raise ValueError("Dark threshold must be below bright threshold")
        return self


class SpeciesConfig(ConfigBase):
    species: Species
    enabled: bool
    config_version: int = Field(ge=1)
    model: ModelConfig
    crop: CropConfig
    quality: QualityConfig


def load_species_configs(directory: Path) -> dict[Species, SpeciesConfig]:
    configs = {}
    for species in Species:
        config = SpeciesConfig.model_validate(
            yaml.safe_load((directory / f"{species.value}.yaml").read_text(encoding="utf-8"))
        )
        if config.species != species:
            raise ValueError(f"Species mismatch in {species.value}.yaml")
        configs[species] = config
    return configs
