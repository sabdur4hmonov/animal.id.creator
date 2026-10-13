"""Audit probes; generated data stays under ignored work/audit_20261013/."""

import hashlib
import json
import sqlite3
import sys
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / "work/audit_20261013"
WORK.mkdir(parents=True, exist_ok=True)
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "research"), str(ROOT)]
import cv2
import numpy as np
from app.core.auth import Principal
from app.core.business_config import load_business_configs
from app.core.database import Base, get_session
from app.core.settings import get_settings
from app.core.species import Species, load_species_configs
from app.main import app
from app.models.capture import Capture
from app.schemas.valuation import KeypointMeasurements, ValuationRequest
from app.services.detection import NoseDetector
from app.services.quality_control import check_quality
from app.services.valuation import estimate_weight, measure_keypoints
from biolivestock_research.dataset import Sample, validate_samples
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

output = Path(tempfile.mkdtemp(prefix="probe-", dir=WORK))
engine = create_engine(
    "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
)
Base.metadata.create_all(engine)
sessions = sessionmaker(bind=engine, expire_on_commit=False)


def session_override():
    with sessions() as session:
        yield session


app.dependency_overrides[get_session] = session_override
metadata = {
    "animal_id": "AUDIT-001",
    "species": "cattle",
    "operator_id": "operator-1",
    "timestamp": datetime.now(UTC).isoformat(),
    "gps": None,
}
image = np.random.default_rng(7).integers(50, 201, (480, 640, 3), dtype=np.uint8)
jpeg = cv2.imencode(".jpg", image)[1].tobytes()
results = {}
with TestClient(app, raise_server_exceptions=False) as client:
    app.state.settings = get_settings().model_copy(
        update={"storage_root": output / "storage"}
    )
    # These persistence probes never need a real model, even if one is installed later.
    app.state.detector = NoseDetector(output / "absent_models")
    app.state.credentials = [
        Principal(
            operator_id="operator-1",
            role="operator",
            token_sha256=hashlib.sha256(b"audit-only").hexdigest(),
        )
    ]
    client.headers["Authorization"] = "Bearer audit-only"

    def post(values, key):
        return client.post(
            "/api/v1/captures",
            headers={"Idempotency-Key": key},
            data={"metadata": json.dumps(values)},
            files={"image": ("probe.jpg", jpeg, "image/jpeg")},
        )

    real_commit = engine.dialect.do_commit

    def commit_then_lost_ack(connection):
        real_commit(connection)
        raise sqlite3.OperationalError(
            "Audit fault injection: lost COMMIT acknowledgement"
        )

    with patch.object(engine.dialect, "do_commit", commit_then_lost_ack):
        failed = post(metadata, "a" * 32)
    with sessions() as session:
        record = session.scalar(select(Capture))
        results["ambiguous_commit"] = {
            "first_http": failed.status_code,
            "database_row_exists": record is not None,
            "image_exists": (output / "storage" / record.file_path).exists()
            if record
            else None,
        }
    retry = post(metadata, "a" * 32)
    results["ambiguous_commit"]["retry_http"] = retry.status_code
    results["ambiguous_commit"]["retry_image_exists"] = (
        output / "storage" / retry.json()["file_path"]
    ).exists()
    results["reserved_id"] = {
        "server_http": post({**metadata, "animal_id": "CON"}, "b" * 32).status_code
    }
    results["utc_overflow"] = {
        "server_http": post(
            {**metadata, "timestamp": "0001-01-01T00:00:00+14:00"}, "c" * 32
        ).status_code
    }
app.dependency_overrides.clear()
engine.dispose()

truncated = output / "truncated.jpg"
truncated.write_bytes(jpeg[:-100])
sample = Sample(
    sample_id="truncated",
    species=Species.cattle,
    animal_id="A",
    session_id="S",
    split="train",
    role="train",
    image_path=truncated.name,
    sha256=hashlib.sha256(truncated.read_bytes()).hexdigest(),
    reviewed_muzzle=True,
)
validate_samples([sample], output, Species.cattle)
results["truncated_jpeg"] = {"manifest_validation": "accepted"}
try:
    with Image.open(truncated) as im:
        im.convert("RGB").load()
except OSError as exc:
    results["truncated_jpeg"]["decode_error"] = str(exc)


def point(x, y):
    return {"x": x, "y": y, "z": 0, "confidence": 1}


config = load_business_configs(ROOT / "business_configs")[Species.cattle]
base = {
    "coordinate_system": "calibrated_3d",
    "reference_start": point(0, 0),
    "reference_end": point(10, 0),
    "reference_length_cm": 10,
    "body_start": point(0, 0),
    "body_end": point(150, 0),
}
results["self_intersecting_contour"] = {}
for name, corners in [
    ("ordered", [(0, 0), (45, 0), (45, 45), (0, 45)]),
    ("crossed", [(0, 0), (45, 45), (45, 0), (0, 45)]),
]:
    points = KeypointMeasurements.model_validate(
        {**base, "chest_contour": [point(*p) for p in corners]}
    )
    request = ValuationRequest(
        species="cattle", method="schoorl", adult=True, keypoints=points, currency="UZS"
    )
    results["self_intersecting_contour"][name] = {
        "girth_cm": str(measure_keypoints(points, config)[0]),
        "weight_kg": str(estimate_weight(request, config)["live_weight_kg"]),
    }

clipped = np.zeros((960, 1280, 3), np.uint8)
levels = np.random.default_rng(7).integers(160, 256, (480, 640), dtype=np.uint8)
clipped[1::2, 1::2] = levels[:, :, None]
cv2.imwrite(str(WORK / "clipped.jpg"), clipped, [cv2.IMWRITE_JPEG_QUALITY, 95])
quality = check_quality(
    cv2.imread(str(WORK / "clipped.jpg")),
    load_species_configs(ROOT / "species_configs")[Species.cattle].quality,
)
results["server_clipped_jpeg_quality"] = quality.model_dump()

(WORK / "backend_results.json").write_text(json.dumps(results, indent=2), "utf-8")
print(json.dumps(results, indent=2))
