from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import cv2
import numpy as np
import pytest
from pydantic import ValidationError

from app.core.security_config import load_security_configs
from app.core.settings import get_settings
from app.core.species import Species
from app.schemas.capture import CaptureMetadata
from app.schemas.telemetry import DeviceSignals, GPSEvidence
from app.services.anti_spoofing import ground_distance, image_signals, metadata_signals, scan_risk
from tests.test_api import post


@pytest.fixture
def security_config():
    return load_security_configs(get_settings().security_config_dir)[Species.cattle]


def test_synthetic_periodic_texture_is_flagged_without_liveness_verdict(security_config, metadata):
    x = np.arange(512)
    wave = np.uint8(128 + 70 * np.sin(2 * np.pi * x / 12))
    gray = np.tile(wave, (384, 1))
    image = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    report = scan_risk(image, CaptureMetadata.model_validate(metadata), datetime.now(UTC), security_config)
    assert "periodic_texture_possible_moire" in report["image"]["flags"]
    assert report["liveness_verdict"] == "not_assessed"
    assert report["real_world_accuracy_verified"] is False


def test_synthetic_glare_and_paper_rectangle(security_config):
    image = np.full((384, 512, 3), 80, np.uint8)
    cv2.rectangle(image, (70, 60), (440, 320), (255, 255, 255), -1)
    result = image_signals(image, security_config)
    assert "specular_highlight_possible_reflection" in result["flags"]
    assert "rectangle_possible_screen_or_paper" in result["flags"]
    assert result["presentation_medium"] == "undetermined"


def test_random_control_and_flat_images_do_not_make_screen_claim(security_config, sharp):
    result = image_signals(sharp, security_config)
    assert "periodic_texture_possible_moire" not in result["flags"]
    assert result["presentation_medium"] == "undetermined"
    assert (
        image_signals(np.full((128, 128, 3), 128, np.uint8), security_config)["periodic_peak_fraction"] == 0
    )
    disabled = security_config.model_copy(update={"enabled": False})
    assert image_signals(sharp, disabled)["status"] == "disabled"


def test_mock_root_and_emulator_are_untrusted_claims(security_config, metadata):
    metadata["device_signals"] = {"source": "android_heuristic", "is_rooted": True, "is_emulator": True}
    metadata["gps_evidence"] = {
        "source": "android_location",
        "is_mock": True,
        "accuracy_m": 500,
        "observed_at": (datetime.now(UTC) - timedelta(hours=1)).isoformat(),
    }
    result = metadata_signals(CaptureMetadata.model_validate(metadata), datetime.now(UTC), security_config)
    assert set(result["flags"]) >= {
        "client_reports_rooted_device",
        "client_reports_emulator",
        "client_reports_mock_location",
        "location_low_accuracy",
        "location_time_mismatch",
    }
    assert result["client_evidence_trusted"] is False


def test_location_speed_and_time_checks(security_config, metadata):
    now = datetime.now(UTC)
    metadata.update(timestamp=now.isoformat(), gps={"latitude": 41.3, "longitude": 69.2})
    previous = SimpleNamespace(
        id="previous", timestamp=now - timedelta(seconds=1), gps={"latitude": 40.7, "longitude": -74}
    )
    result = metadata_signals(CaptureMetadata.model_validate(metadata), now, security_config, previous)
    assert "implausible_location_speed" in result["flags"]
    previous.timestamp = now
    assert (
        "location_jump_same_timestamp"
        in metadata_signals(CaptureMetadata.model_validate(metadata), now, security_config, previous)["flags"]
    )
    previous.timestamp = now + timedelta(seconds=1)
    assert (
        "capture_time_out_of_order"
        in metadata_signals(CaptureMetadata.model_validate(metadata), now, security_config, previous)["flags"]
    )
    assert ground_distance(previous.gps, previous.gps) == 0
    assert ground_distance({"latitude": 0, "longitude": 179.9}, {"latitude": 0, "longitude": -179.9}) < 23000


@pytest.mark.parametrize("delta,flag", [(3600, "capture_time_stale"), (-3600, "capture_time_in_future")])
def test_device_clock_anomalies_are_advisory(security_config, metadata, delta, flag):
    now = datetime.now(UTC)
    metadata["timestamp"] = (now - timedelta(seconds=delta)).isoformat()
    metadata["gps"] = None
    result = metadata_signals(CaptureMetadata.model_validate(metadata), now, security_config)
    assert flag in result["flags"] and "location_missing" in result["flags"]
    assert result["reported_device"] is None


@pytest.mark.parametrize("value", ["false", "true", 0, 1])
def test_device_boolean_claims_require_actual_booleans(value):
    with pytest.raises(ValidationError):
        DeviceSignals(source="android_heuristic", is_rooted=value)


def test_invalid_gps_evidence():
    with pytest.raises(ValidationError):
        GPSEvidence(source="android_location", accuracy_m=float("nan"))
    with pytest.raises(ValidationError):
        GPSEvidence(source="android_location", observed_at="2026-10-01T10:00:00")


def test_upload_stores_advisory_signals_and_accepts_reported_mock(client, metadata, jpeg, db_session):
    metadata["gps_evidence"] = {"source": "android_location", "is_mock": True}
    response = post(client, metadata, jpeg)
    assert response.status_code == 201, response.text
    risk = response.json()["risk_signals"]
    assert "client_reports_mock_location" in risk["metadata"]["flags"]
    assert risk["motion_breathing"] == "blocked_on_labeled_video_dataset"
    from app.models.capture import Capture

    assert db_session.get(Capture, response.json()["id"]).risk_signals == risk
