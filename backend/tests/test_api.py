import json
from pathlib import Path

import cv2
import numpy as np
import pytest
from sqlalchemy.exc import OperationalError

from app.core.database import get_session
from app.main import app
from app.services.detection import DetectionResult


def post(client, metadata, content):
    return client.post(
        "/api/v1/captures",
        data={"metadata": json.dumps(metadata)},
        files={"image": ("capture.jpg", content, "image/jpeg")},
    )


def test_health_and_species(client):
    assert client.get("/health").json()["status"] == "ok"
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


def test_failed_commit_removes_images(client, metadata, jpeg):
    class FailingSession:
        def add(self, record):
            pass

        def commit(self):
            raise OperationalError("insert", {}, Exception("database down"))

        def rollback(self):
            pass

    app.dependency_overrides[get_session] = lambda: FailingSession()
    assert post(client, metadata, jpeg).status_code == 503
    assert not list(Path(app.state.settings.storage_root).rglob("*.jpg"))
