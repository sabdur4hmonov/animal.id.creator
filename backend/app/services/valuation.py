"""Deterministic formula arithmetic, not calibrated vision/scale accuracy."""

import math
from decimal import ROUND_HALF_UP, Decimal

import numpy as np

from app.core.business_config import BusinessConfig
from app.schemas.valuation import KeypointMeasurements, ValuationRequest
from app.services.contour import validate_contour


def distance(a, b):
    return math.dist((a.x, a.y, a.z), (b.x, b.y, b.z))


def measure_keypoints(points: KeypointMeasurements, config: BusinessConfig):
    all_points = [
        points.reference_start,
        points.reference_end,
        points.body_start,
        points.body_end,
        *points.chest_contour,
    ]
    if any(point.confidence < config.weight.min_keypoint_confidence for point in all_points):
        raise ValueError("Keypoint confidence below configured threshold")
    reference = distance(points.reference_start, points.reference_end)
    if reference < 1e-6:
        raise ValueError("Calibration reference has zero length")
    scale = float(points.reference_length_cm) / reference
    body = distance(points.body_start, points.body_end) * scale
    contour = points.chest_contour
    if len({(point.x, point.y, point.z) for point in contour}) != len(contour):
        raise ValueError("Chest contour needs distinct ordered points; closure is automatic")
    coordinates = np.array([(point.x, point.y, point.z) for point in contour])
    validate_contour(coordinates, config.weight)
    girth = (
        sum(distance(point, contour[(index + 1) % len(contour)]) for index, point in enumerate(contour))
        * scale
    )
    if not 0 < body <= 500 or not 0 < girth <= 500:
        raise ValueError("Derived measurements outside supported range")
    return Decimal(str(girth)), Decimal(str(body))


def estimate_weight(data: ValuationRequest, config: BusinessConfig):
    if not config.enabled or data.species != config.species:
        raise ValueError("Species valuation is disabled or mismatched")
    girth, length = (
        measure_keypoints(data.keypoints, config)
        if data.keypoints is not None
        else (data.chest_girth_cm, data.body_length_cm)
    )
    if data.method == "schoorl":
        if data.breed_category is not None:
            raise ValueError("Schoorl does not take a breed factor")
        weight = (girth + config.weight.schoorl_offset_cm) ** 2 / config.weight.denominator
        factor = None
    else:
        factor = config.weight.trukhanovsky_factors.get(data.breed_category)
        if factor is None:
            raise ValueError("Select a configured Trukhanovsky breed category")
        weight = girth * length * factor / config.weight.denominator
    return {"live_weight_kg": weight, "chest_girth_cm": girth, "body_length_cm": length, "factor": factor}


def money(value: Decimal) -> str:
    return str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def value_estimate(data: ValuationRequest, config: BusinessConfig, rate):
    measurements = estimate_weight(data, config)
    weight = measurements["live_weight_kg"]
    low, high = weight * config.weight.carcass_yield_min, weight * config.weight.carcass_yield_max
    return {
        "species": data.species,
        "method": data.method,
        "measurement_source": "calibrated_3d_keypoints" if data.keypoints else "provided_measurements",
        "measurements": {
            key: str(value) if value is not None else None for key, value in measurements.items()
        },
        "carcass_yield_range": [str(config.weight.carcass_yield_min), str(config.weight.carcass_yield_max)],
        "carcass_weight_kg_range": [str(low), str(high)],
        "carcass_value_range": [money(low * rate.price_per_kg), money(high * rate.price_per_kg)],
        "currency": rate.currency,
        "price_basis": rate.basis,
        "price_per_kg": str(rate.price_per_kg),
        "market_rate_id": rate.id,
        "price_observed_at": rate.observed_at,
        "price_source": rate.source,
        "config_snapshot": config.model_dump(mode="json"),
        "real_world_accuracy_verified": False,
        "range_interpretation": "Configured yield scenario range, not a statistical confidence interval",
    }
