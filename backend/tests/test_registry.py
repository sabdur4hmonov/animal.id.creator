from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.models.business import Animal
from app.models.registry import AnimalNumberCounter, RegistryReceipt
from tests.test_api import post

OWNER = {"owner_id": "OWNER-01", "name": "Synthetic Farmer"}
NEW_OWNER = {"owner_id": "OWNER-02", "name": "Synthetic Buyer"}


def send(client, path="/api/v1/registry/animals", body=None, key=None, headers=None):
    return client.post(
        path,
        json=body or {"species": "cattle", "owner": OWNER},
        headers={"Idempotency-Key": key or uuid4().hex, **(headers or {})},
    )


def observation(version=1):
    return {
        "expected_version": version,
        "observed_at": datetime.now(UTC).isoformat(),
        "gps": {"latitude": 41.3, "longitude": 69.2},
        "reason": "Synthetic field report",
    }


def test_unique_numbering_replay_and_conflicting_payload(client, db_session):
    key = uuid4().hex
    first = send(client, key=key)
    assert first.status_code == 201, first.text
    assert first.json()["animal_id"] == "M00000001"
    assert send(client, key=key).json() == first.json()
    assert send(client, key=key, body={"species": "cattle", "owner": NEW_OWNER}).status_code == 409
    assert send(client).json()["animal_id"] == "M00000002"
    assert db_session.scalar(select(func.count()).select_from(Animal)) == 2
    assert db_session.scalar(select(func.count()).select_from(RegistryReceipt)) == 2
    assert db_session.get(AnimalNumberCounter, "M").last_number == 2


def test_legacy_lookalike_is_skipped_and_manual_numeric_assignment_blocked(client, db_session):
    db_session.add(
        Animal(
            species="cattle",
            animal_id="m00000001",
            status="open",
            version=1,
            created_at=datetime.now(UTC),
            registered_by="operator-1",
        )
    )
    db_session.commit()
    assert send(client).json()["animal_id"] == "M00000002"
    assert (
        client.post("/api/v1/animals", json={"species": "cattle", "animal_id": "M00000003"}).status_code
        == 409
    )


def test_owner_transfer_preserves_number_history_and_versions(client):
    animal = send(client).json()
    route = f"/api/v1/registry/animals/cattle/{animal['animal_id']}"
    data = {**observation(), "owner": NEW_OWNER}
    key = uuid4().hex
    response = send(client, route + "/owner", data, key)
    assert response.status_code == 200, response.text
    assert response.json()["animal_id"] == animal["animal_id"]
    assert response.json()["owner"] == NEW_OWNER and response.json()["version"] == 2
    assert send(client, route + "/owner", data, key).json() == response.json()
    assert send(client, route + "/owner", {**observation(), "owner": OWNER}).status_code == 409
    events = client.get(route + "/history").json()
    transfer = next(event for event in events if event["action"] == "owner_changed")
    assert transfer["details"]["before"] == OWNER and transfer["details"]["after"] == NEW_OWNER
    assert transfer["actor_id"] == "operator-1" and transfer["details"]["gps"]["latitude"] == 41.3


@pytest.mark.parametrize("state", ["deceased", "slaughtered"])
def test_archiving_retains_id_owner_and_scans_and_never_reuses_number(
    client, metadata, jpeg, db_session, state
):
    animal = send(client).json()
    metadata["animal_id"] = animal["animal_id"]
    scan = post(client, metadata, jpeg).json()
    route = f"/api/v1/registry/animals/cattle/{animal['animal_id']}"
    data = {**observation(), "lifecycle": state, "capture_id": scan["id"]}
    if state == "slaughtered":
        data["facility_id"] = "FACILITY-01"
    key = uuid4().hex
    response = send(client, route + "/retirement", data, key)
    assert response.status_code == 200, response.text
    assert response.json()["lifecycle"] == state and response.json()["owner"] == OWNER
    assert send(client, route + "/retirement", data, key).json() == response.json()
    assert client.get("/api/v1/registry/animals?species=cattle").json() == []
    assert len(client.get("/api/v1/registry/animals?species=cattle&lifecycle=all").json()) == 1
    assert send(client, route + "/owner", {**observation(2), "owner": NEW_OWNER}).status_code == 409
    assert send(client, route + "/retirement", {**data, "expected_version": 2}).status_code == 409
    # Late/offline evidence still attaches to the same archived identity, never reactivates it.
    assert post(client, metadata, jpeg).status_code == 201
    assert client.get(route).json()["lifecycle"] == state
    assert client.get("/api/v1/captures/" + scan["id"]).status_code == 200
    check = client.get(route + "/slaughter-check").json()
    assert check["recorded_slaughter"] == (state == "slaughtered")
    assert check["biometric_identity_verified"] is False and check["independent_slaughter_verified"] is False
    assert check["animal"]["terminal_record"]["capture_stored_sha256"] == scan["stored_sha256"]
    assert send(client).json()["animal_id"] == "M00000002"


def test_nonregistrar_cannot_change_owner_or_retire(client):
    animal = send(client, headers={"Authorization": "Bearer test-admin"}).json()
    route = f"/api/v1/registry/animals/cattle/{animal['animal_id']}"
    assert send(client, route + "/owner", {**observation(), "owner": NEW_OWNER}).status_code == 403
    assert send(client, route + "/retirement", {**observation(), "lifecycle": "deceased"}).status_code == 403
    assert client.get(route).json()["can_manage"] is False


def test_validation_disabled_species_future_time_and_unknown_id(client, metadata, jpeg):
    assert send(client, body={"species": "sheep", "owner": OWNER}).status_code == 422
    assert send(client, body={"species": "cattle", "owner": {**OWNER, "name": "   "}}).status_code == 422
    animal = send(client).json()
    route = f"/api/v1/registry/animals/cattle/{animal['animal_id']}"
    assert (
        send(client, route + "/retirement", {**observation(), "lifecycle": "slaughtered"}).status_code == 422
    )
    data = {
        **observation(),
        "owner": NEW_OWNER,
        "observed_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
    }
    assert send(client, route + "/owner", data).status_code == 422
    assert client.get(route).json()["version"] == 1
    metadata["animal_id"] = "M00009999"
    assert post(client, metadata, jpeg).status_code == 422
    metadata["animal_id"] = animal["animal_id"].lower()
    assert post(client, metadata, jpeg).status_code == 422
    assert client.get("/api/v1/registry/animals/cattle/M00009999/slaughter-check").status_code == 404


def test_credentials_and_request_key_are_required(client):
    assert (
        client.post("/api/v1/registry/animals", json={"species": "cattle", "owner": OWNER}).status_code == 422
    )
    client.headers.pop("Authorization")
    assert send(client).status_code == 401
