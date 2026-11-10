from copy import deepcopy

import pytest
from pydantic import ValidationError

from app.core.business_config import (
    AdvisoryMatchingConfig,
    ArConfig,
    BurstCaptureConfig,
    BusinessConfig,
    load_business_configs,
)
from app.core.settings import get_settings
from app.core.species import Species


def test_ar_is_additive_and_sheep_stays_disabled():
    configs = load_business_configs(get_settings().business_config_dir)
    cattle = configs[Species.cattle]
    assert cattle.config_version == 5
    assert cattle.ar_policy_version == 3
    assert cattle.advisory_matching.top_k == 3
    assert cattle.burst_capture.best_frame_count == 3
    assert cattle.burst_capture.duration_ms == 4000
    assert cattle.ar.min_repeats == 2
    assert cattle.ar.max_repeats == 3
    assert cattle.ar.min_calibration_animals == 10
    assert cattle.ar.snapshot_min_ratio_animals == 3
    assert cattle.ar.snapshot_min_point_confidence == 0.8
    assert not configs[Species.sheep].enabled
    assert configs[Species.sheep].ar is None
    assert configs[Species.sheep].advisory_matching is None
    assert configs[Species.sheep].burst_capture is None
    legacy = deepcopy(cattle.model_dump())
    legacy.pop("ar")
    legacy.pop("ar_policy_version")
    legacy.pop("advisory_matching")
    legacy["config_version"] = 1
    assert BusinessConfig.model_validate(legacy).ar is None


@pytest.mark.parametrize(
    "changes",
    [
        {"feature_limit": 64, "min_inliers": 65},
        {"patch_size": 30},
        {"lowe_ratio": 1},
        {"top_k": 0},
    ],
)
def test_advisory_thresholds_reject_invalid_values(changes):
    cattle = load_business_configs(get_settings().business_config_dir)[Species.cattle]
    values = cattle.advisory_matching.model_dump()
    with pytest.raises(ValidationError):
        AdvisoryMatchingConfig(**(values | changes))


@pytest.mark.parametrize("change", [{"duration_ms": 9000}, {"best_frame_count": 0}, {"jpeg_quality": 101}])
def test_burst_config_rejects_unbounded_acquisition(change):
    cattle = load_business_configs(get_settings().business_config_dir)[Species.cattle]
    with pytest.raises(ValidationError):
        BurstCaptureConfig(**(cattle.burst_capture.model_dump() | change))


@pytest.mark.parametrize(
    "changes",
    [
        {"min_repeats": 3, "max_repeats": 2},
        {"min_contour_points": 20, "max_contour_points": 10},
        {"min_segment_cm": 100, "max_segment_cm": 100},
        {"min_point_confidence": 0},
        {"min_calibration_animals": 1},
        {"snapshot_min_ratio_animals": 0},
        {"snapshot_min_point_confidence": 0},
        {"snapshot_min_depth_m": 9, "snapshot_max_depth_m": 8},
    ],
)
def test_invalid_ar_gates_fail_configuration_load(changes):
    with pytest.raises(ValidationError):
        ArConfig(**changes)
