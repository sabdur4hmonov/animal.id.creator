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
    contour_max_planarity_error_ratio: float = Field(default=0.01, gt=0, le=0.1)
    contour_geometric_epsilon_ratio: float = Field(default=1e-6, gt=0, le=1e-3)

    @model_validator(mode="after")
    def valid_ranges(self):
        if self.carcass_yield_min > self.carcass_yield_max:
            raise ValueError("Carcass yield bounds must be ordered")
        if any(not value.is_finite() or not 0 < value <= 10 for value in self.trukhanovsky_factors.values()):
            raise ValueError("Invalid Trukhanovsky factors")
        return self


class ArConfig(ConfigBase):
    # Engineering gates, not measured animal-accuracy guarantees.
    min_contour_points: int = Field(default=8, ge=3, le=128)
    max_contour_points: int = Field(default=128, ge=3, le=256)
    min_repeats: int = Field(default=2, ge=2, le=3)
    max_repeats: int = Field(default=3, ge=2, le=3)
    max_repeat_difference_pct: float = Field(default=5, gt=0, le=100)
    min_calibration_animals: int = Field(default=10, ge=3, le=10000)
    max_scale_weight_age_days: int = Field(default=7, ge=0, le=30)
    min_segment_cm: float = Field(default=10, gt=0, le=500)
    max_segment_cm: float = Field(default=500, gt=0, le=500)
    max_session_seconds: int = Field(default=180, ge=10, le=600)
    max_depth_age_ms: int = Field(default=100, ge=1, le=1000)
    min_point_confidence: float = Field(default=0.8, gt=0, le=1)
    max_point_distance_m: float = Field(default=0.03, gt=0, le=0.1)
    max_anchor_drift_m: float = Field(default=0.03, gt=0, le=0.1)
    max_scale_check_error_pct: float = Field(default=5, gt=0, le=25)
    snapshot_min_ratio_animals: int = Field(default=3, ge=1, le=10000)
    snapshot_min_depth_m: float = Field(default=0.2, gt=0, le=10)
    snapshot_max_depth_m: float = Field(default=8, gt=0, le=65)
    snapshot_min_point_confidence: float = Field(default=0.8, gt=0, le=1)
    snapshot_max_depth_pixels: int = Field(default=1048576, ge=1, le=4194304)

    @model_validator(mode="after")
    def ordered(self):
        if (
            self.min_contour_points > self.max_contour_points
            or self.min_repeats > self.max_repeats
            or self.min_segment_cm >= self.max_segment_cm
            or self.snapshot_min_depth_m >= self.snapshot_max_depth_m
        ):
            raise ValueError("AR limits must be ordered")
        return self


class AdvisoryMatchingConfig(ConfigBase):
    # Engineering defaults for human-reviewed candidates; not calibrated accuracy.
    max_image_side: int = Field(ge=128, le=1024)
    center_crop_fraction: float = Field(gt=0.25, le=1)
    feature_limit: int = Field(ge=64, le=2048)
    pyramid_scale: float = Field(gt=1, le=2)
    pyramid_levels: int = Field(ge=1, le=16)
    edge_threshold: int = Field(ge=1, le=100)
    patch_size: int = Field(ge=3, le=99)
    fast_threshold: int = Field(ge=1, le=100)
    lowe_ratio: float = Field(gt=0, lt=1)
    ransac_reprojection_px: float = Field(gt=0, le=20)
    ransac_iterations: int = Field(ge=10, le=5000)
    ransac_confidence: float = Field(gt=0, lt=1)
    min_inliers: int = Field(ge=4, le=2048)
    min_inlier_ratio: float = Field(gt=0, le=1)
    top_k: int = Field(ge=1, le=10)
    thumbnail_max_side: int = Field(ge=64, le=512)

    @model_validator(mode="after")
    def valid_feature_settings(self):
        if self.min_inliers > self.feature_limit or self.patch_size % 2 == 0:
            raise ValueError("Invalid advisory feature settings")
        return self


class BurstCaptureConfig(ConfigBase):
    duration_ms: int = Field(ge=3000, le=5000)
    sample_interval_ms: int = Field(ge=50, le=1000)
    best_frame_count: int = Field(ge=1, le=5)
    max_analyzed_frames: int = Field(ge=5, le=100)
    max_frame_pixels: int = Field(ge=307200, le=16777216)
    jpeg_quality: int = Field(ge=80, le=100)
    soft_blur_ratio: float = Field(gt=0, lt=1)


class SidePhotoConfig(ConfigBase):
    max_scale_age_days: int = Field(ge=0, le=30)
    suggested_distance_min_m: float = Field(gt=0, le=20)
    suggested_distance_max_m: float = Field(gt=0, le=20)

    @model_validator(mode="after")
    def distance_order(self):
        if self.suggested_distance_min_m > self.suggested_distance_max_m:
            raise ValueError("Side photo distance bounds must be ordered")
        return self


class HealthHistoryConfig(ConfigBase):
    description_max_length: int = Field(ge=1, le=500)
    veterinarian_max_length: int = Field(ge=1, le=120)
    notes_max_length: int = Field(ge=1, le=1000)


class OwnershipHistoryConfig(ConfigBase):
    max_price_uzs: int = Field(ge=0, le=10**15)
    notes_max_length: int = Field(ge=1, le=1000)


class BusinessConfig(ConfigBase):
    species: Species
    enabled: bool
    config_version: int = Field(ge=1)
    ar_policy_version: int | None = Field(default=None, ge=1)
    weight: WeightConfig
    ar: ArConfig | None = None
    advisory_matching: AdvisoryMatchingConfig | None = None
    burst_capture: BurstCaptureConfig | None = None
    side_photos: SidePhotoConfig | None = None
    health_history: HealthHistoryConfig | None = None
    ownership_history: OwnershipHistoryConfig | None = None


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
