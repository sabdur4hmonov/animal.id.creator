import json
from pathlib import Path

import cv2
import numpy as np
import pytest
from sqlalchemy import func, select
from sqlalchemy.exc import OperationalError

from app.core.database import get_session
from app.main import app
from app.models.capture import Capture
from app.services import collection
from app.services.detection import DetectionResult, DetectionUnavailable, FramingError


def post(client, metadata, content):
    return client.post(
        "/api/v1/captures",
        data={"metadata": json.dumps(metadata)},
        files={"image": ("capture.jpg", content, "image/jpeg")},
    )


def test_health_and_species(client):
    assert client.get("/health").json()["status"] == "ok"
    assert client.get("/health").json()["capabilities"]["idempotent_capture_uploads"] is True
    configs = {c["species"]: c for c in client.get("/api/v1/species").json()}
    assert configs["cattle"]["enabled"]
    assert not configs["sheep"]["enabled"]


def test_pending_upload_persists_metadata_and_image(client, metadata, jpeg):
    response = post(client, metadata, jpeg)
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["crop_status"] == "pending_model"
    assert result["crop_path"] is None
    assert result["species"] == "cattle"
    assert result["gps"] == metadata["gps"]
    assert result["file_path"].startswith("cattle/COW-001/")
    assert (app.state.settings.storage_root / result["file_path"]).is_file()
    with next(app.dependency_overrides[get_session]()) as session:
        from app.models.capture import Capture

        record = session.get(Capture, result["id"])
        assert record.config_snapshot["species"] == "cattle"
        assert record.operator_id == metadata["operator_id"]


def test_detector_crop_persists(client, metadata, jpeg, sharp, monkeypatch):
    # The model is an explicit test double; no claim of real inference accuracy.
    monkeypatch.setattr(
        app.state.detector,
        "detect",
        lambda *args: DetectionResult(sharp[100:350, 150:450], {"species": "cattle", "confidence": 0.9}),
    )
    response = post(client, metadata, jpeg)
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["crop_status"] == "cropped"
    assert result["crop_quality"]["passed"]
    crop = cv2.imread(str(app.state.settings.storage_root / result["crop_path"]))
    assert crop.shape == (250, 300, 3)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("species", "sheep"),
        ("species", "horse"),
        ("animal_id", "../escape"),
        ("animal_id", "CON"),
        ("operator_id", "  "),
        ("timestamp", "2026-01-01T10:00:00"),
        ("gps", {"latitude": 91, "longitude": 0}),
    ],
)
def test_invalid_metadata(client, metadata, jpeg, field, value):
    metadata[field] = value
    assert post(client, metadata, jpeg).status_code == 422
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


@pytest.mark.parametrize("coordinate", ["latitude", "longitude"])
@pytest.mark.parametrize("value", [float("nan"), float("inf"), float("-inf")])
def test_nonfinite_gps_returns_serializable_validation_error(client, metadata, jpeg, coordinate, value):
    metadata["gps"][coordinate] = value
    response = post(client, metadata, jpeg)
    assert response.status_code == 422
    assert response.json()["detail"][0]["loc"] == ["gps", coordinate]
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


@pytest.mark.parametrize("raw_metadata", ["{invalid", "null", "[]", '{"extra": NaN}'])
def test_malformed_metadata_is_rejected_without_persistence(client, jpeg, db_session, raw_metadata):
    response = client.post(
        "/api/v1/captures",
        data={"metadata": raw_metadata},
        files={"image": ("capture.jpg", jpeg, "image/jpeg")},
    )
    assert response.status_code == 422
    assert isinstance(response.json()["detail"], list)
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 0
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


@pytest.mark.parametrize(
    ("error", "status", "detail"),
    [
        (FramingError("no_muzzle_detected"), 422, {"stage": "framing", "reason": "no_muzzle_detected"}),
        (
            FramingError("multiple_muzzles_detected"),
            422,
            {"stage": "framing", "reason": "multiple_muzzles_detected"},
        ),
        (
            DetectionUnavailable("Checkpoint could not be loaded or used"),
            503,
            "Checkpoint could not be loaded or used",
        ),
    ],
)
def test_detector_failure_does_not_save_capture(
    client, metadata, jpeg, db_session, monkeypatch, error, status, detail
):
    def fail_detection(*args):
        raise error

    monkeypatch.setattr(app.state.detector, "detect", fail_detection)
    response = post(client, metadata, jpeg)
    assert response.status_code == status
    assert response.json()["detail"] == detail
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 0
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


def test_rejected_crop_does_not_save_original(client, metadata, jpeg, db_session, monkeypatch):
    monkeypatch.setattr(
        app.state.detector,
        "detect",
        lambda *args: DetectionResult(np.zeros((200, 200, 3), np.uint8), {}),
    )
    response = post(client, metadata, jpeg)
    assert response.status_code == 422
    assert response.json()["detail"]["stage"] == "crop"
    assert "too_dark" in response.json()["detail"]["quality"]["reasons"]
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 0
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


def test_optional_gps_and_timestamp_use_utc_storage_date(client, metadata, jpeg):
    metadata["gps"] = None
    metadata["timestamp"] = "2026-10-01T00:30:00+05:00"
    metadata["operator_id"] = "  operator-1  "
    response = post(client, metadata, jpeg)
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["gps"] is None
    assert result["file_path"].startswith("cattle/COW-001/2026-09-30/")
    assert result["operator_id"] == "operator-1"
    assert result["timestamp"].startswith("2026-09-30T19:30:00")


def test_invalid_and_blurry_images(client, metadata):
    assert post(client, metadata, b"not an image").status_code == 422
    content = cv2.imencode(".jpg", np.full((480, 640, 3), 128, np.uint8))[1].tobytes()
    response = post(client, metadata, content)
    assert response.status_code == 422
    assert "blurry" in response.json()["detail"]["quality"]["reasons"]


def test_upload_limit(client, metadata, jpeg):
    app.state.settings.max_upload_bytes = 10
    assert post(client, metadata, jpeg).status_code == 413


def test_pixel_limit(client, metadata, jpeg):
    app.state.settings.max_image_pixels = 100
    assert post(client, metadata, jpeg).status_code == 422


def test_uncertain_commit_retains_images(client, metadata, jpeg, db_session, monkeypatch):
    def failed_commit():
        raise OperationalError("insert", {}, Exception("database down"))

    monkeypatch.setattr(db_session, "commit", failed_commit)
    app.dependency_overrides[get_session] = lambda: db_session
    assert post(client, metadata, jpeg).status_code == 503
    assert len(list(Path(app.state.settings.storage_root).rglob("*.jpg"))) == 1


def test_crop_write_failure_removes_saved_original(client, metadata, jpeg, sharp, db_session, monkeypatch):
    monkeypatch.setattr(
        app.state.detector,
        "detect",
        lambda *args: DetectionResult(sharp[100:350, 150:450], {}),
    )
    real_write = collection.write_image

    def fail_crop_write(root, metadata, capture_id, kind, image):
        if kind == "muzzle":
            raise OSError("Simulated disk failure")
        return real_write(root, metadata, capture_id, kind, image)

    monkeypatch.setattr(collection, "write_image", fail_crop_write)
    response = post(client, metadata, jpeg)
    assert response.status_code == 503
    assert response.json()["detail"] == "Capture could not be saved; please retry"
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 0
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


def test_health_reports_database_unavailable(client):
    class UnavailableSession:
        def execute(self, query):
            raise OperationalError("SELECT 1", {}, Exception("database down"))

    app.dependency_overrides[get_session] = lambda: UnavailableSession()
    response = client.get("/health")
    assert response.status_code == 503
    assert response.json()["detail"] == "Database unavailable"
