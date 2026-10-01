import pytest
from pydantic import ValidationError

from app.core.species import QualityConfig


@pytest.mark.parametrize("value", [float("inf"), float("nan")])
def test_blur_threshold_must_be_finite(config, value):
    values = config.quality.model_dump()
    values["blur_min_variance"] = value
    with pytest.raises(ValidationError):
        QualityConfig.model_validate(values)
