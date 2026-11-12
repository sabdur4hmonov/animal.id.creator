"""Synthetic-only API/SQL evidence for the dedicated backlog stack on 18001."""

import argparse
import base64
import json
import re
import secrets
import subprocess
import time
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import cv2
import httpx
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "chorvam-backlog-20261111"
COMPOSE = ROOT / "backend/docker-compose.verify.yml"


def sql(query):
    result = subprocess.run(
        [
            "docker",
            "compose",
            "-p",
            PROJECT,
            "-f",
            str(COMPOSE),
            "exec",
            "-T",
            "db",
            "psql",
            "-U",
            "biolivestock",
            "-Atc",
            query,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return result


def verify_health(client):
    response = client.post(
        "/api/v1/registry/animals",
        headers={"Idempotency-Key": uuid4().hex},
        json={
            "species": "cattle",
            "owner": {"owner_id": "SYNTHETIC", "name": "Synthetic verification"},
        },
    )
    assert response.status_code == 201, response.status_code
    label = response.json()["animal_id"]
    path = f"/api/v1/registry/animals/cattle/{label}/health"
    key = uuid4().hex
    body = {
        "local_event_key": uuid4().hex,
        "kind": "examination",
        "event_date": datetime.now(UTC).date().isoformat(),
        "description": "SYNTHETIC ONLY",
        "notes": "",
    }
    first = client.post(path, json=body, headers={"Idempotency-Key": key})
    assert first.status_code == 201, first.text
    assert (
        client.post(path, json=body, headers={"Idempotency-Key": key}).json()
        == first.json()
    )
    event = first.json()
    assert event["verified_by_veterinarian"] is False
    correction = client.post(
        path,
        json={
            **body,
            "local_event_key": uuid4().hex,
            "correction_of": event["id"],
            "description": "Synthetic correction",
        },
        headers={"Idempotency-Key": uuid4().hex},
    )
    assert correction.status_code == 201, correction.text
    assert len(client.get(path).json()) == 2
    rejected = []
    for query in [
        f"UPDATE health_events SET notes='changed' WHERE id='{event['id']}'",
        f"DELETE FROM health_events WHERE id='{event['id']}'",
    ]:
        result = sql(query)
        assert result.returncode != 0
        rejected.append(True)
    assert (
        sql(
            f"SELECT count(*) FROM health_events WHERE animal_id='{label}'"
        ).stdout.strip()
        == "2"
    )
    return {
        "animal_id": label,
        "migration": sql("SELECT version_num FROM alembic_version").stdout.strip(),
        "event_id": event["id"],
        "idempotent_replay": True,
        "correction_retained": True,
        "sql_mutations_rejected": rejected,
    }


def verify_ownership(client):
    issued = client.post(
        "/api/v1/registry/animals",
        headers={"Idempotency-Key": uuid4().hex},
        json={
            "species": "cattle",
            "owner": {"owner_id": "SYNTHETIC-A", "name": "Synthetic seller"},
        },
    )
    assert issued.status_code == 201
    label = issued.json()["animal_id"]
    root = f"/api/v1/registry/animals/cattle/{label}"
    key = uuid4().hex
    body = {
        "expected_version": 1,
        "owner": {"owner_id": "SYNTHETIC-B", "name": "Synthetic buyer"},
        "observed_at": datetime.now(UTC).isoformat(),
        "gps": None,
        "reason": "Synthetic sale",
        "price_uzs": 25000000,
        "currency": "UZS",
    }
    first = client.post(root + "/owner", json=body, headers={"Idempotency-Key": key})
    assert first.status_code == 200, first.text
    assert (
        client.post(root + "/owner", json=body, headers={"Idempotency-Key": key}).json()
        == first.json()
    )
    assert (
        client.post(
            root + "/owner",
            json={
                **body,
                "owner": {"owner_id": "SYNTHETIC-C", "name": "Synthetic conflict"},
            },
            headers={"Idempotency-Key": uuid4().hex},
        ).status_code
        == 409
    )
    events = client.get(root + "/history").json()
    transfer = [e for e in events if e["action"] == "owner_changed"]
    assert len(transfer) == 1
    assert transfer[0]["details"]["price_uzs"] == 25000000
    return {
        "animal_id": label,
        "idempotent_transfer": True,
        "stale_version_rejected": True,
        "price_audited": True,
    }


def verify_qr(client):
    issued = client.post(
        "/api/v1/registry/animals",
        headers={"Idempotency-Key": uuid4().hex},
        json={
            "species": "cattle",
            "owner": {"owner_id": "SYNTHETIC-PRIVATE", "name": "PRIVATE OWNER NAME"},
        },
    )
    assert issued.status_code == 201
    label = issued.json()["animal_id"]
    root = f"/api/v1/registry/animals/cattle/{label}"
    report = {
        "expected_version": 1,
        "observed_at": datetime.now(UTC).isoformat(),
        "gps": None,
        "reason": "PRIVATE NOTES",
        "lifecycle": "slaughtered",
        "facility_id": "SYNTHETIC-FACILITY",
    }
    assert (
        client.post(
            root + "/retirement", json=report, headers={"Idempotency-Key": uuid4().hex}
        ).status_code
        == 200
    )
    key = uuid4().hex
    qr = client.post(
        root + "/verification-codes", json={}, headers={"Idempotency-Key": key}
    )
    assert qr.status_code == 201, qr.text
    code = qr.json()
    assert (
        client.post(
            root + "/verification-codes", json={}, headers={"Idempotency-Key": key}
        ).json()
        == code
    )
    png = cv2.imdecode(
        np.frombuffer(base64.b64decode(code["qr_png_base64"]), dtype=np.uint8),
        cv2.IMREAD_GRAYSCALE,
    )
    assert cv2.QRCodeDetector().detectAndDecode(png)[0] == code["url"]
    with httpx.Client(timeout=30) as public:
        response = public.get(code["url"] + "?lang=en")
        assert response.status_code == 200 and label in response.text
        assert (
            "PRIVATE OWNER NAME" not in response.text
            and "PRIVATE NOTES" not in response.text
        )
        assert "not a laboratory test" in response.text
    revoked = client.post(
        root + f"/verification-codes/{code['code_id']}/revoke",
        json={"reason": "Synthetic revoke"},
        headers={"Idempotency-Key": uuid4().hex},
    )
    assert revoked.status_code == 200
    assert httpx.get(code["url"], timeout=30).status_code == 404
    assert (
        sql(
            f"DELETE FROM code_revocations WHERE code_id='{code['code_id']}'"
        ).returncode
        != 0
    )
    return {
        "animal_id": label,
        "qr_decodes_exact_url": True,
        "private_fields_absent": True,
        "revocation_retained": True,
    }


def verify_panel(client):
    response = client.post(
        "/api/v1/registry/animals",
        json={
            "species": "cattle",
            "owner": {"owner_id": "SYNTHETIC", "name": "Synthetic portal owner"},
        },
        headers={"Idempotency-Key": uuid4().hex},
    )
    assert response.status_code == 201, response.text
    label = response.json()["animal_id"]
    path = f"/api/v1/registry/animals/cattle/{label}/field-summaries"
    body = {
        "local_event_key": uuid4().hex,
        "observed_at": datetime.now(UTC).isoformat(),
        "tag": "SYNTHETIC-PANEL-" + label,
    }
    key = uuid4().hex
    first = client.post(path, json=body, headers={"Idempotency-Key": key})
    assert first.status_code == 201, first.text
    assert (
        client.post(path, json=body, headers={"Idempotency-Key": key}).json()
        == first.json()
    )
    for lang in ("uz_Latn", "ru"):
        listing = client.get("/panel", params={"q": body["tag"], "lang": lang})
        assert listing.status_code == 200 and label in listing.text
        detail = client.get(f"/panel/animals/cattle/{label}", params={"lang": lang})
        assert detail.status_code == 200 and body["tag"] in detail.text
        assert detail.headers["cache-control"] == "no-store"
    session = client.post("/panel/session")
    assert session.status_code == 200 and "Secure" in session.headers["set-cookie"]
    assert (
        sql(f"DELETE FROM field_summaries WHERE id='{first.json()['id']}'").returncode
        != 0
    )
    return {
        "animal_id": label,
        "uz_ru_ssr_search": True,
        "summary_replay": True,
        "summary_delete_rejected": True,
        "secure_cookie_issued": True,
        "real_browser_https_cookie_roundtrip": "not_yet_verified; item 6",
    }


def verify_roles(client):
    created = client.post(
        "/api/v1/registry/animals",
        json={
            "species": "cattle",
            "owner": {"owner_id": "SYNTHETIC", "name": "Synthetic role trial"},
        },
        headers={"Idempotency-Key": uuid4().hex},
    )
    assert created.status_code == 201
    label = created.json()["animal_id"]
    root = f"/api/v1/registry/animals/cattle/{label}"
    directory = ROOT / "data/verification-backlog-20261111/secrets"
    users = []
    for role in ("veterinar", "bank_viewer", "bank_officer"):
        suffix = uuid4().hex[:12]
        username = "synthetic-" + suffix
        operator_id = "SYNTHETIC-" + suffix.upper()
        password = secrets.token_urlsafe(24)
        filename = "portal-password-" + suffix + ".txt"
        (directory / filename).write_text(password, "utf-8")
        command = [
            "docker",
            "compose",
            "-p",
            PROJECT,
            "-f",
            str(COMPOSE),
            "exec",
            "-T",
            "api",
            "python",
            "/srv/tools/manage_users.py",
            "create",
            "--username",
            username,
            "--operator-id",
            operator_id,
            "--role",
            role,
            "--actor",
            "SYNTHETIC-CLI",
            "--password-file",
            "/srv/secrets/" + filename,
        ]
        cli = subprocess.run(command, capture_output=True, text=True, check=False)
        assert cli.returncode == 0, (
            "Synthetic CLI creation failed; no credentials printed"
        )
        with httpx.Client(base_url=str(client.base_url), timeout=60) as portal:
            login = portal.post(
                "/panel/login",
                json={"username": username, "password": password},
                headers={"X-Chorvam-Login": "1"},
            )
            assert login.status_code == 200, login.status_code
            assert (
                "Secure" in login.headers["set-cookie"]
                and "HttpOnly" in login.headers["set-cookie"]
            )
            # Explicit loopback HTTP header exercises authorization, not HTTPS browser transport.
            # The deployment milestone performs a real TLS cookie roundtrip with a trusted test CA.
            portal.headers["Cookie"] = login.headers["set-cookie"].split(";", 1)[0]
            page = portal.get("/panel")
            assert page.status_code == 200 and role in page.text
            csrf = re.search(r'name="csrf-token" content="([^"]+)"', page.text)[1]
            portal.headers["X-CSRF-Token"] = csrf
            health = portal.post(
                root + "/health",
                json={
                    "local_event_key": uuid4().hex,
                    "kind": "examination",
                    "event_date": datetime.now(UTC).date().isoformat(),
                    "description": "SYNTHETIC ROLE CHECK",
                },
                headers={"Idempotency-Key": uuid4().hex},
            )
            assert health.status_code == (201 if role == "veterinar" else 403)
            if role == "veterinar":
                assert health.json()["verified_by_veterinarian"] is True
            finance = portal.patch(
                f"/api/v1/animals/cattle/{label}/status",
                json={
                    "status": "collateral",
                    "expected_version": 1,
                    "reason": "Synthetic bank role review",
                },
            )
            assert finance.status_code == (200 if role == "bank_officer" else 403)
            assert (
                portal.post(
                    "/api/v1/registry/animals",
                    json={
                        "species": "cattle",
                        "owner": {"owner_id": "X", "name": "Synthetic"},
                    },
                    headers={"Idempotency-Key": uuid4().hex},
                ).status_code
                == 403
            )
        hashed = sql(
            f"SELECT password_hash LIKE '$argon2id$%' FROM user_accounts WHERE username='{username}'"
        )
        assert hashed.stdout.strip() == "t"
        users.append(
            {
                "username": username,
                "operator_id": operator_id,
                "role": role,
                "password_file": filename,
            }
        )
    (directory / "portal-users.json").write_text(json.dumps(users, indent=2), "utf-8")
    audit_id = sql(
        "SELECT id FROM access_audit ORDER BY received_at DESC LIMIT 1"
    ).stdout.strip()
    assert sql(f"DELETE FROM access_audit WHERE id='{audit_id}'").returncode != 0
    return {
        "animal_id": label,
        "cli_argon2_users": True,
        "vet_health_verified": True,
        "bank_read_write_separation": True,
        "access_audit_delete_rejected": True,
        "authorization_http_explicit_cookie": True,
        "browser_https_transport": "unverified until item 6",
        "users_manifest": "secrets/portal-users.json",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--stage",
        choices=["health", "ownership", "qr", "panel", "roles"],
        required=True,
    )
    args = parser.parse_args()
    binding = subprocess.run(
        ["docker", "compose", "-p", PROJECT, "-f", str(COMPOSE), "port", "api", "8000"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    assert binding == "127.0.0.1:18001", (
        "Dedicated verification API binding differs; no requests sent"
    )
    root = ROOT / "data/verification-backlog-20261111"
    keys = json.loads((root / "secrets/tokens.json").read_text("utf-8"))
    with httpx.Client(
        base_url="http://127.0.0.1:18001",
        headers={"Authorization": "Bearer " + keys["operator"]["token"]},
        timeout=60,
    ) as client:
        for _ in range(20):
            try:
                if client.get("/health", timeout=2).status_code == 200:
                    break
            except httpx.TransportError:
                pass
            time.sleep(0.5)
        else:
            raise RuntimeError("Dedicated API is not ready; no mutations attempted")
        evidence = {
            "health": verify_health,
            "ownership": verify_ownership,
            "qr": verify_qr,
            "panel": verify_panel,
            "roles": verify_roles,
        }[args.stage](client)
    evidence.update(
        stage=args.stage,
        verified_at=datetime.now(UTC).isoformat(),
        synthetic_only=True,
        project=PROJECT,
    )
    output = root / f"evidence-{args.stage}-{uuid4().hex}.json"
    output.write_text(json.dumps(evidence, indent=2), "utf-8")
    print(f"Verified {args.stage}; synthetic evidence: {output}")


if __name__ == "__main__":
    main()
