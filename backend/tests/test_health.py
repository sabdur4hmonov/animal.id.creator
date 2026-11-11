from uuid import uuid4

from sqlalchemy import select

from app.models.health import HealthEvent


def animal(client):
    response = client.post(
        "/api/v1/registry/animals",
        headers={"Idempotency-Key": uuid4().hex},
        json={"species": "cattle", "owner": {"owner_id": "SYNTHETIC", "name": "Synthetic owner"}},
    )
    assert response.status_code == 201
    return response.json()["animal_id"]


def payload(**changes):
    return {
        "local_event_key": uuid4().hex,
        "kind": "vaccination",
        "event_date": "2026-11-01",
        "description": "Synthetic record",
        "veterinarian_name": "Synthetic veterinarian",
        "notes": "",
        "correction_of": None,
    } | changes


def test_health_replay_correction_and_role_cannot_be_forged(client, db_session):
    label = animal(client)
    url = f"/api/v1/registry/animals/cattle/{label}/health"
    body = payload()
    key = uuid4().hex
    first = client.post(url, json=body, headers={"Idempotency-Key": key})
    assert first.status_code == 201
    assert first.json()["verified_by_veterinarian"] is False
    assert client.post(url, json=body, headers={"Idempotency-Key": key}).json() == first.json()
    from app.core.species import Species

    original_config = client.app.state.business_configs[Species.cattle]
    client.app.state.business_configs[Species.cattle] = original_config.model_copy(
        update={
            "health_history": original_config.health_history.model_copy(update={"description_max_length": 1})
        }
    )
    assert client.post(url, json=body, headers={"Idempotency-Key": key}).json() == first.json()
    client.app.state.business_configs[Species.cattle] = original_config
    assert client.post(url, json=body, headers={"Idempotency-Key": uuid4().hex}).status_code == 409
    corrected = payload(correction_of=first.json()["id"], description="Synthetic correction")
    second = client.post(url, json=corrected, headers={"Idempotency-Key": uuid4().hex})
    assert second.status_code == 201
    assert (
        client.post(
            url, json=payload(correction_of=first.json()["id"]), headers={"Idempotency-Key": uuid4().hex}
        ).status_code
        == 409
    )
    assert len(client.get(url).json()) == 2
    assert len(db_session.scalars(select(HealthEvent)).all()) == 2
    assert (
        client.post(
            url, json=payload(verified_by_veterinarian=True), headers={"Idempotency-Key": uuid4().hex}
        ).status_code
        == 422
    )


def test_health_rejects_disabled_species_foreign_correction_and_invalid_dates(client):
    label = animal(client)
    other = animal(client)
    root = f"/api/v1/registry/animals/cattle/{label}/health"
    first = client.post(root, json=payload(), headers={"Idempotency-Key": uuid4().hex}).json()
    assert (
        client.post(
            f"/api/v1/registry/animals/cattle/{other}/health",
            json=payload(correction_of=first["id"]),
            headers={"Idempotency-Key": uuid4().hex},
        ).status_code
        == 422
    )
    for change in [
        {"event_date": "2099-01-01"},
        {"description": "  "},
        {"event_date": "2026-02-30"},
        {"kind": "diagnosis_ai"},
    ]:
        assert (
            client.post(root, json=payload(**change), headers={"Idempotency-Key": uuid4().hex}).status_code
            == 422
        )
    assert client.get(f"/api/v1/registry/animals/sheep/{label}/health").status_code == 422
