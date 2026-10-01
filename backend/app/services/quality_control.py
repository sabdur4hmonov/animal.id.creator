"""First-pass QC; thresholds need calibration on real farm captures."""

import cv2
import numpy as np

from app.core.species import QualityConfig
from app.schemas.capture import QualityResult


def check_quality(image: np.ndarray, config: QualityConfig) -> QualityResult:
    height, width = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    # Measure exposure before resizing: averaging can hide clipped pixels.
    histogram = cv2.calcHist([gray], [0], None, [256], [0, 256]).ravel().astype(np.float64)
    histogram /= histogram.sum()
    scale = min(1.0, config.analysis_max_dimension / max(width, height))
    if scale < 1:
        gray = cv2.resize(
            gray, (max(1, round(width * scale)), max(1, round(height * scale))), interpolation=cv2.INTER_AREA
        )
    variance = float(cv2.Laplacian(gray, cv2.CV_64F, ksize=1).var())
    brightness = float(np.dot(np.arange(256), histogram))
    dark = float(histogram[: config.dark_pixel_threshold + 1].sum())
    bright = float(histogram[config.bright_pixel_threshold :].sum())
    reasons = []
    # Allow portrait captures: compare long and short dimensions.
    actual, required = sorted((width, height)), sorted((config.min_width, config.min_height))
    if any(a < r for a, r in zip(actual, required)):
        reasons.append("resolution_too_low")
    if variance < config.blur_min_variance:
        reasons.append("blurry")
    if brightness < config.brightness_min or dark > config.max_dark_fraction:
        reasons.append("too_dark")
    if brightness > config.brightness_max or bright > config.max_bright_fraction:
        reasons.append("too_bright")
    score = min(1.0, variance / config.blur_min_variance)
    score *= max(0.0, 1.0 - max(dark, bright))
    if "resolution_too_low" in reasons:
        score = 0.0
    # TODO: calibrate thresholds per species, camera and field lighting.
    # TODO: add pose / occlusion checks after labeled examples exist.
    # Framing uses detected boxes in detection.py; a missing model cannot assess it.
    return QualityResult(
        passed=not reasons,
        score=round(score, 4),
        blur_variance=variance,
        brightness=brightness,
        dark_fraction=dark,
        bright_fraction=bright,
        width=width,
        height=height,
        reasons=reasons,
    )
