from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import event, func, select

from app.core.species import Species
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
    assert first.json()["animal_id"] == "MAA00000001"
    assert send(client, key=key).json() == first.json()
    assert send(client, key=key, body={"species": "cattle", "owner": NEW_OWNER}).status_code == 409
    assert send(client).json()["animal_id"] == "MAA00000002"
    assert db_session.scalar(select(func.count()).select_from(Animal)) == 2
    assert db_session.scalar(select(func.count()).select_from(RegistryReceipt)) == 2
    assert db_session.get(AnimalNumberCounter, "M").last_number == 2


def test_legacy_lookalike_is_skipped_and_manual_numeric_assignment_blocked(client, db_session):
    db_session.add(
        Animal(
            species="cattle",
            animal_id="maa00000001",
            status="open",
            version=1,
            created_at=datetime.now(UTC),
            registered_by="operator-1",
        )
    )
    db_session.commit()
    assert send(client).json()["animal_id"] == "MAA00000002"
    assert (
        client.post("/api/v1/animals", json={"species": "cattle", "animal_id": "MAA00000003"}).status_code
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
    assert send(client).json()["animal_id"] == "MAA00000002"


@pytest.mark.parametrize(
    "seed,expected",
    [
        (99_999_998, ["MAA99999999", "MAB00000001"]),
        (26 * 99_999_999 - 1, ["MAZ99999999", "MBA00000001"]),
    ],
)
def test_api_rollover_advances_same_counter_without_reset(client, db_session, seed, expected):
    db_session.add(AnimalNumberCounter(prefix="M", last_number=seed))
    db_session.commit()
    for animal_id in expected:
        response = send(client)
        assert response.status_code == 201, response.text
        assert response.json()["animal_id"] == animal_id
    db_session.expire_all()
    assert db_session.get(AnimalNumberCounter, "M").last_number == seed + 2


def test_old_id_receipt_and_capture_survive_format_upgrade(client, db_session, metadata, jpeg):
    current = client.app.state.species_configs[Species.cattle]
    old = current.model_copy(update={"numbering": current.numbering.model_copy(update={"series_letters": 0})})
    client.app.state.species_configs[Species.cattle] = old
    key = uuid4().hex
    try:
        legacy = send(client, key=key).json()
        assert legacy["animal_id"] == "M00000001"
    finally:
        client.app.state.species_configs[Species.cattle] = current
    assert send(client, key=key).json() == legacy
    assert send(client).json()["animal_id"] == "MAA00000002"
    metadata["animal_id"] = legacy["animal_id"]
    assert post(client, metadata, jpeg).status_code == 201
    route = "/api/v1/registry/animals/cattle/M00000001"
    assert send(client, route + "/owner", {**observation(), "owner": NEW_OWNER}).status_code == 200
    assert client.get(route).json()["animal_id"] == "M00000001"
    db_session.expire_all()
    assert db_session.get(AnimalNumberCounter, "M").last_number == 2


def test_final_series_exhaustion_does_not_create_receipt_or_reset(client, db_session):
    maximum = 676 * 99_999_999
    db_session.add(AnimalNumberCounter(prefix="M", last_number=maximum - 1))
    db_session.commit()
    final_key = uuid4().hex
    last = send(client, key=final_key)
    assert last.status_code == 201 and last.json()["animal_id"] == "MZZ99999999"
    assert send(client).status_code == 503
    assert send(client, key=final_key).json() == last.json()
    db_session.expire_all()
    assert db_session.get(AnimalNumberCounter, "M").last_number == maximum
    assert db_session.scalar(select(func.count()).select_from(RegistryReceipt)) == 1


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


def test_registry_page_and_detail_use_one_coherent_query(client, db_session):
    first = send(client).json()
    send(client)
    route = f"/api/v1/registry/animals/cattle/{first['animal_id']}"
    assert send(client, route + "/owner", {**observation(), "owner": NEW_OWNER}).status_code == 200
    assert send(client, route + "/retirement", {**observation(2), "lifecycle": "deceased"}).status_code == 200
    db_session.add(
        Animal(
            species="cattle",
            animal_id="LEGACY-SNAPSHOT",
            status="insured",
            version=1,
            registered_by="operator-1",
            created_at=datetime.now(UTC),
        )
    )
    db_session.commit()
    selects = []

    def record_sql(connection, cursor, statement, parameters, context, executemany):
        if statement.lstrip().upper().startswith("SELECT"):
            selects.append(statement)

    engine = db_session.get_bind()
    event.listen(engine, "before_cursor_execute", record_sql)
    try:
        result = client.get("/api/v1/registry/animals?species=cattle&lifecycle=all").json()
        assert len(selects) == 1
        by_id = {row["animal_id"]: row for row in result}
        assert by_id[first["animal_id"]]["version"] == 3
        assert by_id[first["animal_id"]]["owner"] == NEW_OWNER
        assert by_id[first["animal_id"]]["lifecycle"] == "deceased"
        assert by_id[first["animal_id"]]["terminal_record"]["owner_at_recording"] == NEW_OWNER
        assert by_id["LEGACY-SNAPSHOT"]["lifecycle"] == "active"
        assert by_id["LEGACY-SNAPSHOT"]["status"] == "insured"
        selects.clear()
        assert client.get(route + "/slaughter-check").json()["animal"]["version"] == 3
        assert len(selects) == 1
    finally:
        event.remove(engine, "before_cursor_execute", record_sql)


def test_capture_attachment_rejects_wrong_animal_and_permissions_without_closing(client, metadata, jpeg):
    first = send(client).json()
    second = send(client).json()
    metadata["animal_id"] = second["animal_id"]
    scan = post(client, metadata, jpeg).json()
    route = f"/api/v1/registry/animals/cattle/{first['animal_id']}"
    data = {**observation(), "lifecycle": "slaughtered", "facility_id": "SITE-1", "capture_id": scan["id"]}
    assert send(client, route + "/retirement", data).status_code == 422
    assert client.get(route).json()["version"] == 1
    assert client.get(route).json()["lifecycle"] == "active"
    metadata["animal_id"] = first["animal_id"]
    metadata["operator_id"] = "admin-1"
    client.headers["Authorization"] = "Bearer test-admin"
    try:
        scan = post(client, metadata, jpeg).json()
    finally:
        client.headers["Authorization"] = "Bearer test-operator"
    assert send(client, route + "/retirement", {**data, "capture_id": scan["id"]}).status_code == 403
    assert client.get(route).json()["version"] == 1
    assert client.get(route).json()["lifecycle"] == "active"
