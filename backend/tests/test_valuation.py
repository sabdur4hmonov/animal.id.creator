from datetime import UTC, datetime, timedelta
from decimal import Decimal

import numpy as np
import pytest
from pydantic import ValidationError
from sqlalchemy import func, select

from app.core.business_config import load_business_configs
from app.core.settings import get_settings
from app.core.species import Species
from app.models.valuation import MarketRate
from app.schemas.valuation import KeypointMeasurements, ValuationRequest
from app.services.valuation import estimate_weight, measure_keypoints

ADMIN = {"Authorization": "Bearer test-admin"}


@pytest.fixture
def weight_config():
    return load_business_configs(get_settings().business_config_dir)[Species.cattle]


def request_data(**kwargs):
    return {
        "species": "cattle",
        "method": "schoorl",
        "adult": True,
        "chest_girth_cm": "180",
        "currency": "UZS",
        **kwargs,
    }


def quote(**kwargs):
    return {
        "species": "cattle",
        "currency": "UZS",
        "basis": "carcass",
        "price_per_kg": "100",
        "observed_at": datetime.now(UTC).isoformat(),
        "source": "Synthetic test price",
        **kwargs,
    }


def point(x, y, z=0, confidence=1):
    return {"x": x, "y": y, "z": z, "confidence": confidence}


@pytest.fixture
def keypoints():
    # 45 cm square is a geometry fixture, not a reconstruction of animal anatomy.
    return {
        "coordinate_system": "calibrated_3d",
        "reference_start": point(0, 0),
        "reference_end": point(10, 0),
        "reference_length_cm": 10,
        "body_start": point(0, 0),
        "body_end": point(150, 0),
        "chest_contour": [point(0, 0), point(45, 0), point(45, 45), point(0, 45)],
    }


@pytest.mark.parametrize(
    "method,category,expected",
    [
        ("schoorl", None, "408.04"),
        ("trukhanovsky", "dairy", "540"),
        ("trukhanovsky", "beef", "675"),
    ],
)
def test_formula_examples(weight_config, method, category, expected):
    data = ValuationRequest.model_validate(
        request_data(method=method, breed_category=category, body_length_cm=150)
    )
    assert estimate_weight(data, weight_config)["live_weight_kg"] == Decimal(expected)


def test_keypoints_metric_scale_and_confidence(weight_config, keypoints):
    data = KeypointMeasurements.model_validate(keypoints)
    assert measure_keypoints(data, weight_config) == (Decimal(180), Decimal(150))
    data.reference_length_cm = Decimal(20)
    assert measure_keypoints(data, weight_config) == (Decimal(360), Decimal(300))
    data.body_start.confidence = 0.5
    with pytest.raises(ValueError, match="confidence"):
        measure_keypoints(data, weight_config)


@pytest.mark.parametrize("fault", ["zero_reference", "duplicate_contour", "line_contour"])
def test_invalid_geometry(weight_config, keypoints, fault):
    if fault == "zero_reference":
        keypoints["reference_end"] = keypoints["reference_start"]
    elif fault == "duplicate_contour":
        keypoints["chest_contour"][3] = keypoints["chest_contour"][0]
    else:
        keypoints["chest_contour"] = [point(x, 0) for x in (0, 10, 20, 30)]
    with pytest.raises(ValueError):
        measure_keypoints(KeypointMeasurements.model_validate(keypoints), weight_config)


@pytest.mark.parametrize("corners", [
    [(0, 0), (45, 45), (45, 0), (0, 45)],
    [(0, 0), (45, 0), (20, 0), (45, 45), (0, 45)],
    [(0, 0), (45, 0), (45, 45), (0, 45), (0, 20), (45, 20)],
])
def test_crossed_or_retraced_contour_is_rejected(weight_config, keypoints, corners):
    keypoints["chest_contour"] = [point(*corner) for corner in corners]
    with pytest.raises(ValueError, match="intersects|overlaps|retraces"):
        measure_keypoints(KeypointMeasurements.model_validate(keypoints), weight_config)


def test_nonplanar_contour_is_rejected(weight_config, keypoints):
    keypoints["chest_contour"][0]["z"] = 20
    with pytest.raises(ValueError, match="planar"):
        measure_keypoints(KeypointMeasurements.model_validate(keypoints), weight_config)


def test_valid_rotated_and_translated_contour_keeps_measurements(weight_config, keypoints):
    rotation = np.array([[1, 0, 0], [0, 0.6, -0.8], [0, 0.8, 0.6]])
    for p in [keypoints["reference_start"], keypoints["reference_end"],
              keypoints["body_start"], keypoints["body_end"], *keypoints["chest_contour"]]:
        values = rotation @ np.array([p["x"], p["y"], p["z"]]) + np.array([100, -200, 30])
        p.update(dict(zip(("x", "y", "z"), values)))
    girth, body = measure_keypoints(KeypointMeasurements.model_validate(keypoints), weight_config)
    assert float(girth) == pytest.approx(180)
    assert float(body) == pytest.approx(150)


@pytest.mark.parametrize("value", [0, -1, float("nan"), float("inf"), "500.1"])
def test_invalid_measurements(value):
    with pytest.raises(ValidationError):
        ValuationRequest.model_validate(request_data(chest_girth_cm=value))


def test_keypoint_input_cannot_mix_with_tape_or_planar_images(keypoints):
    with pytest.raises(ValidationError, match="Choose"):
        ValuationRequest.model_validate(request_data(keypoints=keypoints))
    keypoints["coordinate_system"] = "side_photo_pixels"
    with pytest.raises(ValidationError):
        KeypointMeasurements.model_validate(keypoints)


def test_market_price_history_roles_and_expected_quote(client, db_session):
    assert client.get("/api/v1/market-rates/cattle?currency=UZS").status_code == 404
    assert client.post("/api/v1/valuation", json=request_data()).status_code == 409
    assert client.post("/api/v1/admin/market-rates", json=quote()).status_code == 403
    first = client.post("/api/v1/admin/market-rates", json=quote(), headers=ADMIN)
    assert first.status_code == 201, first.text
    assert client.post("/api/v1/admin/market-rates", json=quote(), headers=ADMIN).status_code == 409
    second = client.post(
        "/api/v1/admin/market-rates",
        json=quote(price_per_kg="125.1234", expected_latest_id=first.json()["id"]),
        headers=ADMIN,
    )
    assert second.status_code == 201
    assert client.get("/api/v1/market-rates/cattle?currency=UZS").json()["id"] == second.json()["id"]
    assert db_session.scalar(select(func.count()).select_from(MarketRate)) == 2
    assert client.get("/api/v1/market-rates/cattle?currency=bad").status_code == 422


def test_valuation_yield_money_and_provenance(client, keypoints):
    rate = client.post("/api/v1/admin/market-rates", json=quote(), headers=ADMIN).json()
    response = client.post("/api/v1/valuation", json=request_data())
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["measurements"]["live_weight_kg"] == "408.04"
    assert result["carcass_value_range"] == ["20402.00", "23666.32"]
    assert result["market_rate_id"] == rate["id"]
    assert result["real_world_accuracy_verified"] is False
    synthetic = request_data(keypoints=keypoints)
    synthetic.pop("chest_girth_cm")
    assert (
        client.post("/api/v1/valuation", json=synthetic).json()["measurement_source"]
        == "calibrated_3d_keypoints"
    )
    assert client.post("/api/v1/valuation", json=request_data(species="sheep")).status_code == 422
    assert client.post("/api/v1/valuation", json=request_data(adult=False)).status_code == 422
    assert (
        client.post(
            "/api/v1/valuation",
            json=request_data(method="trukhanovsky", body_length_cm=150, breed_category="unknown"),
        ).status_code
        == 422
    )


@pytest.mark.parametrize(
    "invalid",
    [
        {"price_per_kg": 0},
        {"price_per_kg": "NaN"},
        {"price_per_kg": "1.00001"},
        {"source": " "},
        {"basis": "live_weight"},
        {"observed_at": (datetime.now(UTC) + timedelta(days=1)).isoformat()},
        {"species": "sheep"},
    ],
)
def test_market_input_validation(client, invalid):
    assert client.post("/api/v1/admin/market-rates", json=quote(**invalid), headers=ADMIN).status_code == 422
