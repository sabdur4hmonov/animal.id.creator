import re
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import select
from test_health import animal

from app.models.business import AuditEvent
from app.models.portal import BrowserSession, FieldSummary


def summary(client, label, **values):
    body = {"local_event_key": uuid4().hex, "observed_at": "2026-11-01T00:00:00Z", **values}
    key = uuid4().hex
    path = f"/api/v1/registry/animals/cattle/{label}/field-summaries"
    first = client.post(path, json=body, headers={"Idempotency-Key": key})
    assert first.status_code == 201, first.text
    assert client.post(path, json=body, headers={"Idempotency-Key": key}).json() == first.json()
    return first.json()


def test_private_panel_tag_search_weights_xss_and_versioned_finance(client, db_session):
    label = animal(client)
    summary(client, label, tag="BIRKA <script>bad()</script>")
    summary(
        client,
        label,
        weight={
            "mode": "snapshot",
            "trukhanovsky_kg": "402.123456",
            "schoorl_kg": "411.000000",
            "source_key": uuid4().hex,
            "config_sha256": "a" * 64,
        },
    )
    summary(client, label, scale_kg="405.5")
    assert len(db_session.scalars(select(FieldSummary)).all()) == 3
    for lang in ("uz_Latn", "ru"):
        found = client.get(f"/panel?lang={lang}&q=BIRKA")
        assert found.status_code == 200 and label in found.text
        assert label not in client.get(f"/panel?lang={lang}&q=missing").text
        profile = client.get(f"/panel/animals/cattle/{label}?lang={lang}")
        assert profile.status_code == 200
        assert "402.123456" in profile.text and "405.5" in profile.text
        assert "<script>bad()</script>" not in profile.text
        assert "&lt;script&gt;bad()&lt;/script&gt;" in profile.text
        assert 'id="finance"' not in profile.text
        assert profile.headers["cache-control"] == "no-store"
        assert "frame-ancestors 'none'" in profile.headers["content-security-policy"]
    client.headers["Authorization"] = "Bearer test-admin"
    assert 'id="finance"' in client.get(f"/panel/animals/cattle/{label}").text
    path = f"/api/v1/animals/cattle/{label}/status"
    data = {"status": "collateral", "expected_version": 1, "reason": "Synthetic bank review"}
    assert client.patch(path, json=data).status_code == 200
    assert client.patch(path, json=data).status_code == 409
    assert (
        db_session.scalar(select(AuditEvent).where(AuditEvent.action == "status_changed")).details["reason"]
        == data["reason"]
    )
    history = client.get(f"/panel/animals/cattle/{label}/history")
    assert history.status_code == 200 and "Synthetic bank review" in history.text


def test_secure_browser_session_csrf_logout_expiry_and_credential_revocation(client, db_session):
    label = animal(client)
    client.base_url = "https://testserver"
    response = client.post("/panel/session")
    assert response.status_code == 200
    cookie = response.headers["set-cookie"]
    assert "HttpOnly" in cookie and "Secure" in cookie and "SameSite=strict" in cookie
    assert "test-operator" not in cookie
    client.headers.pop("Authorization")
    assert client.get("/panel").status_code == 200
    csrf = re.search(r'name="csrf-token" content="([^"]+)"', client.get("/panel").text)[1]
    assert client.post("/panel/logout").status_code == 403
    assert client.post("/panel/logout", headers={"X-CSRF-Token": csrf}).status_code == 200
    assert client.get("/panel").status_code == 401
    client.headers["Authorization"] = "Bearer test-operator"
    client.post("/panel/session")
    client.headers.pop("Authorization")
    row = db_session.scalars(select(BrowserSession).order_by(BrowserSession.created_at.desc())).first()
    row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    db_session.commit()
    assert client.get("/panel").status_code == 401
    client.headers["Authorization"] = "Bearer test-operator"
    client.post("/panel/session")
    client.headers.pop("Authorization")
    client.app.state.credentials = client.app.state.credentials[1:]
    assert client.get("/panel").status_code == 401
    assert client.get(f"/panel/animals/cattle/{label}").status_code == 401


def test_summary_rejects_invented_fields_and_disabled_species(client):
    label = animal(client)
    path = f"/api/v1/registry/animals/cattle/{label}/field-summaries"
    base = {"local_event_key": uuid4().hex, "observed_at": "2026-11-01T00:00:00Z"}
    for changes in (
        {},
        {"tag": " "},
        {"tag": "X", "scale_kg": 400},
        {"scale_kg": "NaN"},
        {"tag": "X", "raw_depth": "private"},
    ):
        assert (
            client.post(path, json=base | changes, headers={"Idempotency-Key": uuid4().hex}).status_code
            == 422
        )
    assert client.get("/panel?species=sheep").status_code == 422
