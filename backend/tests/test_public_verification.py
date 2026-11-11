import base64
from uuid import uuid4

import cv2
import numpy as np
from test_health import animal

from app.core import rate_limit


def issue_slaughter(client):
    label = animal(client)
    root = f"/api/v1/registry/animals/cattle/{label}"
    report = {
        "expected_version": 1,
        "observed_at": "2026-11-01T00:00:00Z",
        "gps": {"latitude": 41.3, "longitude": 69.2},
        "reason": "PRIVATE-SLAUGHTER-NOTES",
        "lifecycle": "slaughtered",
        "facility_id": "SYNTHETIC-FACILITY",
    }
    assert (
        client.post(root + "/retirement", json=report, headers={"Idempotency-Key": uuid4().hex}).status_code
        == 200
    )
    return label, root


def test_qr_requires_recorded_slaughter_and_configured_public_origin(client):
    label = animal(client)
    path = f"/api/v1/registry/animals/cattle/{label}/verification-codes"
    assert client.post(path, json={}, headers={"Idempotency-Key": uuid4().hex}).status_code == 409
    label, root = issue_slaughter(client)
    assert (
        client.post(
            root + "/verification-codes", json={}, headers={"Idempotency-Key": uuid4().hex}
        ).status_code
        == 503
    )


def test_qr_png_replay_privacy_and_append_only_revocation(client):
    client.app.state.settings = client.app.state.settings.model_copy(
        update={"public_origin": "https://verify.synthetic.invalid"}
    )
    label, root = issue_slaughter(client)
    key = uuid4().hex
    first = client.post(root + "/verification-codes", json={}, headers={"Idempotency-Key": key})
    assert first.status_code == 201, first.text
    qr = first.json()
    assert client.post(root + "/verification-codes", json={}, headers={"Idempotency-Key": key}).json() == qr
    image = cv2.imdecode(
        np.frombuffer(base64.b64decode(qr["qr_png_base64"]), dtype=np.uint8), cv2.IMREAD_GRAYSCALE
    )
    assert cv2.QRCodeDetector().detectAndDecode(image)[0] == qr["url"]
    token = qr["url"].rsplit("/", 1)[1]
    assert len(token) == 43
    another = client.post(
        root + "/verification-codes", json={}, headers={"Idempotency-Key": uuid4().hex}
    ).json()
    assert another["url"] != qr["url"]
    client.headers.pop("Authorization")
    for lang in ["uz_Latn", "uz_Cyrl", "ru", "en"]:
        response = client.get(f"/verify/{token}?lang={lang}")
        assert response.status_code == 200
        assert label in response.text and "SYNTHETIC-FACILITY" in response.text
        for private in [
            "Synthetic owner",
            "SYNTHETIC-OWNER",
            "PRIVATE-SLAUGHTER-NOTES",
            "41.3",
            "69.2",
            "operator-1",
            "price_uzs",
            "gps",
        ]:
            assert private not in response.text
        assert response.headers["cache-control"] == "no-store"
    client.headers["Authorization"] = "Bearer test-operator"
    revoke_key = uuid4().hex
    path = root + f"/verification-codes/{qr['code_id']}/revoke"
    revoked = client.post(
        path, json={"reason": "Synthetic revocation"}, headers={"Idempotency-Key": revoke_key}
    )
    assert revoked.status_code == 200
    assert (
        client.post(
            path, json={"reason": "Synthetic revocation"}, headers={"Idempotency-Key": revoke_key}
        ).json()
        == revoked.json()
    )
    assert client.get(f"/verify/{token}").status_code == 404
    assert any(code["revoked"] for code in client.get(root + "/verification-codes").json())


def test_public_rate_limit_is_shared_and_ignores_spoofed_forwarded_header(client, monkeypatch):
    monkeypatch.setattr(rate_limit.time, "time", lambda: 1000000)
    client.app.state.settings = client.app.state.settings.model_copy(update={"public_rate_requests": 2})
    token = "A" * 43
    assert client.get(f"/verify/{token}").status_code == 404
    assert client.get(f"/verify/{token}", headers={"X-Forwarded-For": "203.0.113.2"}).status_code == 404
    assert client.get(f"/verify/{token}", headers={"X-Forwarded-For": "203.0.113.3"}).status_code == 429
