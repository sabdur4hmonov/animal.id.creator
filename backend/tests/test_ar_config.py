from copy import deepcopy

import pytest
from pydantic import ValidationError

from app.core.business_config import ArConfig, BusinessConfig, load_business_configs
from app.core.settings import get_settings
from app.core.species import Species


def test_ar_is_additive_and_sheep_stays_disabled():
    configs = load_business_configs(get_settings().business_config_dir)
    cattle = configs[Species.cattle]
    assert cattle.config_version == 2
    assert cattle.ar.min_repeats == 2
    assert cattle.ar.max_repeats == 3
    assert cattle.ar.min_calibration_animals == 10
    assert not configs[Species.sheep].enabled
    assert configs[Species.sheep].ar is None
    legacy = deepcopy(cattle.model_dump())
    legacy.pop("ar")
    legacy["config_version"] = 1
    assert BusinessConfig.model_validate(legacy).ar is None


@pytest.mark.parametrize(
    "changes",
    [
        {"min_repeats": 3, "max_repeats": 2},
        {"min_contour_points": 20, "max_contour_points": 10},
        {"min_segment_cm": 100, "max_segment_cm": 100},
        {"min_point_confidence": 0},
        {"min_calibration_animals": 1},
    ],
)
def test_invalid_ar_gates_fail_configuration_load(changes):
    with pytest.raises(ValidationError):
        ArConfig(**changes)
