import hashlib
import json
from uuid import uuid4

from test_health import animal

from app.models.registry import RegistryReceipt


def transfer(**change):
    return {
        "owner": {"owner_id": "SYNTHETIC-B", "name": "Synthetic buyer"},
        "expected_version": 1,
        "observed_at": "2026-11-01T00:00:00Z",
        "gps": None,
        "reason": "Synthetic transfer",
    } | change


def test_absent_sale_fields_preserve_preexisting_owner_receipt_digest(client, db_session):
    label = animal(client)
    path = f"/api/v1/registry/animals/cattle/{label}/owner"
    key = uuid4().hex
    body = transfer()
    result = client.post(path, json=body, headers={"Idempotency-Key": key})
    assert result.status_code == 200
    legacy = {
        "operation": f"owner:cattle:{label}",
        "body": {**body, "observed_at": "2026-11-01T00:00:00+00:00"},
    }
    expected = hashlib.sha256(
        json.dumps(legacy, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    ).hexdigest()
    assert db_session.get(RegistryReceipt, ("operator-1", key)).payload_sha256 == expected
    assert client.post(path, json=body, headers={"Idempotency-Key": key}).json() == result.json()


def test_optional_whole_uzs_price_is_validated_and_audited(client):
    label = animal(client)
    root = f"/api/v1/registry/animals/cattle/{label}"
    for change in [
        {"price_uzs": 1.5, "currency": "UZS"},
        {"price_uzs": True, "currency": "UZS"},
        {"price_uzs": 5, "currency": "USD"},
        {"price_uzs": -1, "currency": "UZS"},
        {"price_uzs": 1000000000001, "currency": "UZS"},
        {"currency": "UZS"},
    ]:
        assert (
            client.post(
                root + "/owner", json=transfer(**change), headers={"Idempotency-Key": uuid4().hex}
            ).status_code
            == 422
        )
    assert client.get(root).json()["version"] == 1
    key = uuid4().hex
    body = transfer(price_uzs=25000000, currency="UZS")
    first = client.post(root + "/owner", json=body, headers={"Idempotency-Key": key})
    assert first.status_code == 200
    assert client.post(root + "/owner", json=body, headers={"Idempotency-Key": key}).json() == first.json()
    events = client.get(root + "/history").json()
    assert next(e for e in events if e["action"] == "owner_changed")["details"]["price_uzs"] == 25000000
