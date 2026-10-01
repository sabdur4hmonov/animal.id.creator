import json

import pytest
from sqlalchemy import func, select

from app.main import app
from app.models.business import Animal, AuditEvent, DuplicateCase
from app.models.capture import Capture
from tests.test_api import post

ADMIN = {"Authorization": "Bearer test-admin"}


def test_api_requires_keys_and_admin_role(client, metadata, jpeg):
    client.headers.pop("Authorization")
    assert client.get("/health").status_code == 200
    assert client.get("/api/v1/species").status_code == 401
    assert post(client, metadata, jpeg).status_code == 401
    assert client.get("/api/v1/species", headers={"Authorization": "Bearer wrong"}).status_code == 401
    client.headers["Authorization"] = "Bearer test-operator"
    assert client.get("/api/v1/admin/duplicates?species=cattle").status_code == 403
    app.state.credentials = []
    assert client.get("/api/v1/species").status_code == 503


def test_operator_cannot_impersonate_another(client, metadata, jpeg, db_session):
    metadata["operator_id"] = "someone-else"
    assert post(client, metadata, jpeg).status_code == 403
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 0


def test_registration_status_conflicts_and_audit(client, db_session):
    payload = {"species": "cattle", "animal_id": "REGISTER-1"}
    animal = client.post("/api/v1/animals", json=payload)
    assert animal.status_code == 201
    assert animal.json()["status"] == "open"
    assert client.post("/api/v1/animals", json=payload).status_code == 409
    route = "/api/v1/animals/cattle/REGISTER-1/status"
    change = {"status": "insured", "expected_version": 1, "reason": "Policy verified"}
    assert client.patch(route, json=change).status_code == 403
    updated = client.patch(route, json=change, headers=ADMIN)
    assert updated.json()["version"] == 2
    assert updated.json()["status"] == "insured"
    assert client.patch(route, json=change, headers=ADMIN).status_code == 409
    change.update(status="collateral", expected_version=2, reason="Loan record verified")
    assert client.patch(route, json=change, headers=ADMIN).json()["status"] == "collateral"
    assert client.get("/api/v1/animals?species=cattle").json()[0]["animal_id"] == "REGISTER-1"
    assert db_session.scalar(select(func.count()).select_from(AuditEvent)) == 3
    assert client.get("/api/v1/animals?species=cattle&limit=999").status_code == 422
    assert client.post("/api/v1/animals", json={**payload, "species": "sheep"}).status_code == 422


def test_exact_reuse_review_preserves_captures(client, metadata, jpeg, db_session):
    first = post(client, metadata, jpeg).json()
    metadata["animal_id"] = "DIFFERENT-LABEL"
    second = post(client, metadata, jpeg).json()
    assert second["duplicate_summary"]["exact_image_matches"] == 1
    assert second["duplicate_summary"]["biometric_identity_checked"] is False
    cases = client.get("/api/v1/admin/duplicates?species=cattle", headers=ADMIN).json()
    assert len(cases) == 1 and cases[0]["matched_capture_id"] == first["id"]
    case = cases[0]
    route = f"/api/v1/admin/duplicates/{case['id']}"
    review = {"state": "confirmed", "expected_version": 1, "note": "Exact reused image"}
    assert client.patch(route, json=review, headers=ADMIN).json()["reviewed_by"] == "admin-1"
    assert client.patch(route, json=review, headers=ADMIN).status_code == 409
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 2
    assert db_session.scalar(select(func.count()).select_from(Animal)) == 2
    assert db_session.scalar(select(func.count()).select_from(DuplicateCase)) == 1
    saved = db_session.get(Capture, first["id"])
    assert saved.received_at is not None and len(saved.stored_sha256) == 64
    saved.operator_id = "tampered"
    with pytest.raises(ValueError, match="append-only"):
        db_session.commit()
    db_session.rollback()


def test_manual_duplicate_flag_and_validation(client, metadata, jpeg):
    capture = post(client, metadata, jpeg).json()
    response = client.post(
        "/api/v1/admin/duplicates", headers=ADMIN, json={"capture_id": capture["id"], "note": "Review label"}
    )
    assert response.status_code == 201
    assert response.json()["reason"] == "manual_review"
    assert (
        client.post(
            "/api/v1/admin/duplicates", headers=ADMIN, json={"capture_id": "-" * 36, "note": "bad"}
        ).status_code
        == 422
    )
    assert client.get(f"/api/v1/captures/{capture['id']}").status_code == 200
    assert client.get("/api/v1/captures/not-a-uuid").status_code == 422


def test_whole_request_bound_before_multipart(client):
    app.state.settings.max_upload_bytes = 10
    response = client.post("/api/v1/animals", content=b" " * (65536 + 11))
    assert response.status_code == 413
    assert (
        client.post("/api/v1/animals", content="{}", headers={"Content-Length": "invalid"}).status_code == 400
    )


def test_global_validation_does_not_echo_input(client):
    response = client.post(
        "/api/v1/animals",
        content=json.dumps({"species": "cattle", "animal_id": "bad", "extra": float("nan")}),
        headers={"Content-Type": "application/json"},
    )
    assert response.status_code == 422
    assert "input" not in response.json()["detail"][0]
