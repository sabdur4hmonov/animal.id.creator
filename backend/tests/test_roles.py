import json
import secrets
import sys
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import select
from test_health import animal, payload
from test_public_verification import issue_slaughter

from app.core.roles import ROLES
from app.models.accounts import AccessAudit, UserAccount

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from manage_users import apply_change


@pytest.mark.parametrize("role", ROLES)
def test_role_matrix_even_when_identity_matches_registering_operator(client, jpeg, metadata, role):
    label = animal(client)
    root = f"/api/v1/registry/animals/cattle/{label}"
    photo = client.post(
        "/api/v1/captures",
        files={"image": ("synthetic.jpg", jpeg, "image/jpeg")},
        data={"metadata": json.dumps(metadata | {"animal_id": label})},
    )
    assert photo.status_code == 201, photo.text
    slaughter, slaughter_root = issue_slaughter(client)
    client.app.state.settings = client.app.state.settings.model_copy(
        update={"public_origin": "https://verify.synthetic.invalid"}
    )
    client.app.state.credentials[0] = client.app.state.credentials[0].model_copy(update={"role": role})
    writable = role in ("admin", "operator")
    assert client.get("/panel").status_code == 200
    assert client.get(root).json()["can_manage"] is writable
    assert client.get(f"/api/v1/captures/{photo.json()['id']}").status_code == 200
    assert client.post(
        "/api/v1/registry/animals",
        json={"species": "cattle", "owner": {"owner_id": "SYNTHETIC", "name": "Synthetic"}},
        headers={"Idempotency-Key": uuid4().hex},
    ).status_code == (201 if writable else 403)
    assert client.post(
        "/api/v1/animals", json={"species": "cattle", "animal_id": "SYNTHETIC-" + uuid4().hex}
    ).status_code == (201 if writable else 403)
    assert client.post(
        "/api/v1/captures",
        files={"image": ("synthetic.jpg", jpeg, "image/jpeg")},
        data={"metadata": json.dumps(metadata | {"animal_id": label})},
    ).status_code == (201 if writable else 403)
    observation = {"expected_version": 1, "observed_at": "2026-11-01T00:00:00Z", "reason": "Synthetic reason"}
    assert client.post(
        root + "/owner",
        json=observation | {"owner": {"owner_id": "SYNTHETIC-NEW", "name": "Synthetic successor"}},
        headers={"Idempotency-Key": uuid4().hex},
    ).status_code == (200 if writable else 403)
    assert client.post(
        root + "/retirement",
        json=observation | {"expected_version": 2 if writable else 1, "lifecycle": "deceased"},
        headers={"Idempotency-Key": uuid4().hex},
    ).status_code == (200 if writable else 403)
    assert client.post(
        slaughter_root + "/verification-codes", json={}, headers={"Idempotency-Key": uuid4().hex}
    ).status_code == (201 if writable else 403)
    assert client.get(slaughter_root + "/verification-codes").status_code == (200 if writable else 403)
    version = client.get(root).json()["version"]
    assert client.patch(
        f"/api/v1/animals/cattle/{label}/status",
        json={"status": "insured", "expected_version": version, "reason": "Synthetic finance review"},
    ).status_code == (200 if role in ("admin", "bank_officer") else 403)
    assert client.post(
        root + "/field-summaries",
        json={"local_event_key": uuid4().hex, "observed_at": "2026-11-01T00:00:00Z", "tag": "SYNTHETIC"},
        headers={"Idempotency-Key": uuid4().hex},
    ).status_code == (201 if writable else 403)
    health = client.post(
        root + "/health", json=payload(kind="examination"), headers={"Idempotency-Key": uuid4().hex}
    )
    assert health.status_code == (201 if role in ("admin", "operator", "veterinar") else 403)
    if health.status_code == 201:
        assert health.json()["verified_by_veterinarian"] is (role == "veterinar")
    assert client.get(root + "/health").status_code == 200
    assert client.get(f"/panel/animals/cattle/{label}/history").status_code == 200
    assert slaughter


def test_read_only_role_cannot_replay_a_previously_authorized_write(client):
    key = uuid4().hex
    body = {"species": "cattle", "owner": {"owner_id": "SYNTHETIC", "name": "Synthetic"}}
    assert (
        client.post("/api/v1/registry/animals", json=body, headers={"Idempotency-Key": key}).status_code
        == 201
    )
    client.app.state.credentials[0] = client.app.state.credentials[0].model_copy(
        update={"role": "bank_viewer"}
    )
    assert (
        client.post("/api/v1/registry/animals", json=body, headers={"Idempotency-Key": key}).status_code
        == 403
    )


def test_vet_proof_and_corrections_control_public_examination_date(client):
    _, root = issue_slaughter(client)
    client.app.state.settings = client.app.state.settings.model_copy(
        update={"public_origin": "https://verify.synthetic.invalid"}
    )
    qr = client.post(root + "/verification-codes", json={}, headers={"Idempotency-Key": uuid4().hex}).json()
    path = "/verify/" + qr["url"].rsplit("/", 1)[1]
    assert "2026-10-31" not in client.get(path).text
    client.app.state.credentials[0] = client.app.state.credentials[0].model_copy(update={"role": "veterinar"})
    event = client.post(
        root + "/health",
        json=payload(kind="examination", event_date="2026-10-31"),
        headers={"Idempotency-Key": uuid4().hex},
    )
    assert event.status_code == 201 and event.json()["verified_by_veterinarian"]
    assert "2026-10-31" in client.get(path).text
    client.app.state.credentials[0] = client.app.state.credentials[0].model_copy(update={"role": "operator"})
    assert (
        client.post(
            root + "/health",
            json=payload(correction_of=event.json()["id"]),
            headers={"Idempotency-Key": uuid4().hex},
        ).status_code
        == 403
    )
    client.headers["Authorization"] = "Bearer test-admin"
    assert (
        client.post(
            root + "/health",
            json=payload(correction_of=event.json()["id"]),
            headers={"Idempotency-Key": uuid4().hex},
        ).status_code
        == 201
    )
    assert "2026-10-31" not in client.get(path).text


def test_downgraded_admin_cannot_replay_another_operators_transfer_receipt(client):
    label = animal(client)
    path = f"/api/v1/registry/animals/cattle/{label}/owner"
    key = uuid4().hex
    body = {
        "expected_version": 1,
        "observed_at": "2026-11-01T00:00:00Z",
        "reason": "Synthetic administrator transfer",
        "owner": {"owner_id": "SUCCESSOR", "name": "Synthetic successor"},
    }
    client.headers["Authorization"] = "Bearer test-admin"
    assert client.post(path, json=body, headers={"Idempotency-Key": key}).status_code == 200
    client.app.state.credentials[1] = client.app.state.credentials[1].model_copy(update={"role": "operator"})
    assert client.post(path, json=body, headers={"Idempotency-Key": key}).status_code == 403


def create_user(client, db_session, role="operator", username="synthetic-user"):
    password = secrets.token_urlsafe(24)
    apply_change(
        db_session,
        client.app.state.settings,
        "create",
        username,
        actor="SYNTHETIC-CLI",
        operator_id="PASSWORD-" + username,
        role=role,
        password=password,
    )
    db_session.commit()
    return password


def test_password_login_csrf_policy_changes_and_no_plaintext_secret_storage(client, db_session):
    create_user(client, db_session, "admin", "synthetic-admin")
    password = create_user(client, db_session)
    account = db_session.get(UserAccount, "synthetic-user")
    assert account.password_hash.startswith("$argon2id$") and password not in account.password_hash
    client.app.state.settings = client.app.state.settings.model_copy(update={"login_rate_requests": 30})
    client.base_url = "https://testserver"
    client.headers.pop("Authorization")
    headers = {"X-Chorvam-Login": "1", "Origin": "https://testserver"}
    credentials = {"username": "SYNTHETIC-USER", "password": password}
    wrong = client.post(
        "/panel/login", json=credentials | {"password": secrets.token_urlsafe(24)}, headers=headers
    )
    missing = client.post("/panel/login", json=credentials | {"username": "unknown"}, headers=headers)
    assert wrong.status_code == missing.status_code == 401 and wrong.json() == missing.json()
    assert (
        client.post(
            "/panel/login", json=credentials, headers=headers | {"Origin": "https://evil.invalid"}
        ).status_code
        == 403
    )
    assert client.post("/panel/login", json=credentials).status_code == 403
    accepted = client.post("/panel/login", json=credentials, headers=headers)
    assert accepted.status_code == 200
    assert all(x in accepted.headers["set-cookie"] for x in ("Secure", "HttpOnly", "SameSite=strict"))
    assert client.get("/panel").status_code == 200
    assert client.post("/panel/logout").status_code == 403
    apply_change(
        db_session,
        client.app.state.settings,
        "set-role",
        "synthetic-user",
        actor="SYNTHETIC-CLI",
        role="bank_viewer",
    )
    db_session.commit()
    assert client.get("/panel").status_code == 401
    assert client.post("/panel/login", json=credentials, headers=headers).status_code == 200
    assert "bank_viewer" in client.get("/panel").text
    apply_change(db_session, client.app.state.settings, "disable", "synthetic-user", actor="SYNTHETIC-CLI")
    db_session.commit()
    assert client.get("/panel").status_code == 401
    assert client.post("/panel/login", json=credentials, headers=headers).status_code == 401
    audit = db_session.scalars(select(AccessAudit)).all()
    assert {e.action for e in audit} >= {
        "account_created",
        "account_set_role",
        "account_disable",
        "login_failed",
        "login_succeeded",
    }
    assert password not in json.dumps([e.details for e in audit])
    with pytest.raises(ValueError, match="one enabled"):
        apply_change(
            db_session, client.app.state.settings, "disable", "synthetic-admin", actor="SYNTHETIC-CLI"
        )


def test_login_rate_limits_failed_password_and_token_exchange_without_forwarded_header_bypass(client):
    client.app.state.settings = client.app.state.settings.model_copy(update={"login_rate_requests": 2})
    for _ in range(2):
        assert client.post("/panel/session", headers={"Authorization": "Bearer wrong"}).status_code == 401
    limited = client.post(
        "/panel/login",
        json={"username": "unknown", "password": secrets.token_urlsafe(24)},
        headers={"X-Chorvam-Login": "1", "X-Forwarded-For": "203.0.113.1"},
    )
    assert limited.status_code == 429 and "retry-after" in limited.headers


def test_account_specific_rate_window_is_independent_and_username_is_normalized(client):
    client.app.state.settings = client.app.state.settings.model_copy(
        update={"login_rate_requests": 100, "login_account_rate_requests": 2}
    )
    headers = {"X-Chorvam-Login": "1"}
    body = {"username": "UNKNOWN", "password": secrets.token_urlsafe(24)}
    assert client.post("/panel/login", json=body, headers=headers).status_code == 401
    assert (
        client.post("/panel/login", json=body | {"username": "unknown"}, headers=headers).status_code == 401
    )
    assert client.post("/panel/login", json=body, headers=headers).status_code == 429
    assert (
        client.post("/panel/login", json=body | {"username": "another"}, headers=headers).status_code == 401
    )


def test_cli_never_overwrites_accounts_and_password_reset_invalidates_sessions(client, db_session, tmp_path):
    password = create_user(client, db_session)
    settings = client.app.state.settings
    with pytest.raises(ValueError, match="exists"):
        apply_change(
            db_session,
            settings,
            "create",
            "synthetic-user",
            actor="SYNTHETIC-CLI",
            operator_id="ANOTHER",
            role="admin",
            password=secrets.token_urlsafe(24),
        )
    keyfile = tmp_path / "api_keys.json"
    keyfile.write_text(json.dumps([p.model_dump() for p in client.app.state.credentials]), "utf-8")
    with pytest.raises(ValueError, match="API-key principal"):
        apply_change(
            db_session,
            settings.model_copy(update={"auth_config_path": keyfile}),
            "create",
            "unused",
            actor="SYNTHETIC-CLI",
            operator_id="operator-1",
            role="operator",
            password=password,
        )
    with pytest.raises(ValueError, match="12–256"):
        apply_change(
            db_session,
            settings,
            "create",
            "weak",
            actor="SYNTHETIC-CLI",
            operator_id="WEAK",
            role="operator",
            password=" " * 12,
        )
    client.base_url = "https://testserver"
    client.headers.pop("Authorization")
    headers = {"X-Chorvam-Login": "1"}
    body = {"username": "synthetic-user", "password": password}
    assert client.post("/panel/login", json=body, headers=headers).status_code == 200
    client.app.state.credentials = []
    assert client.get("/panel").status_code == 200
    replacement = secrets.token_urlsafe(24)
    apply_change(
        db_session, settings, "reset-password", "synthetic-user", actor="SYNTHETIC-CLI", password=replacement
    )
    db_session.commit()
    assert client.get("/panel").status_code == 401
    assert client.post("/panel/login", json=body, headers=headers).status_code == 401
    assert (
        client.post("/panel/login", json=body | {"password": replacement}, headers=headers).status_code == 200
    )
    assert db_session.get(UserAccount, "weak") is None
