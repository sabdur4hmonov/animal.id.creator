import cv2
import numpy as np
import pytest

from app.services.quality_control import check_quality


def test_sharp_vs_blurred(sharp, config):
    assert check_quality(sharp, config.quality).passed
    blurry = cv2.GaussianBlur(sharp, (31, 31), 8)
    assert "blurry" in check_quality(blurry, config.quality).reasons


@pytest.mark.parametrize(("level", "reason"), [(0, "too_dark"), (255, "too_bright")])
def test_lighting(level, reason, config):
    image = np.full((480, 640, 3), level, np.uint8)
    result = check_quality(image, config.quality)
    assert not result.passed
    assert reason in result.reasons


def test_resolution_and_portrait(sharp, config):
    assert "resolution_too_low" in check_quality(sharp[:100, :100], config.quality).reasons
    assert check_quality(np.rot90(sharp).copy(), config.quality).passed


def test_histogram_detects_clipped_shadows_despite_acceptable_mean(config):
    image = np.full((480, 640, 3), 200, np.uint8)
    image[:, :420] = 0
    result = check_quality(image, config.quality)
    assert result.brightness > config.quality.brightness_min
    assert "too_dark" in result.reasons


@pytest.mark.parametrize(
    ("clipped", "other", "reason", "fraction"),
    [(0, 200, "too_dark", "dark_fraction"), (255, 55, "too_bright", "bright_fraction")],
)
def test_lighting_preserves_clipped_pixels_when_blur_analysis_is_resized(
    config, clipped, other, reason, fraction
):
    # Every 20-pixel group averages to a normal exposure when reduced to one pixel.
    stripe = np.array([clipped] * 14 + [other] * 6, dtype=np.uint8)
    gray = np.tile(stripe, (480, 32))
    image = np.repeat(gray[:, :, None], 3, axis=2)
    full = check_quality(image, config.quality)
    reduced = check_quality(image, config.quality.model_copy(update={"analysis_max_dimension": 32}))
    assert config.quality.brightness_min < reduced.brightness < config.quality.brightness_max
    assert getattr(reduced, fraction) == pytest.approx(0.7)
    assert reduced.brightness == pytest.approx(full.brightness)
    assert reason in reduced.reasons
