"""Synthetic-only API/SQL evidence for the dedicated backlog stack on 18001."""

import argparse
import base64
import json
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--stage", choices=["health", "ownership", "qr", "panel"], required=True
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
