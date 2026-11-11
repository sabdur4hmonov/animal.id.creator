"""Synthetic-only API/SQL evidence for the dedicated backlog stack on 18001."""

import argparse
import json
import subprocess
import time
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import httpx

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=["health", "ownership"], required=True)
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
        evidence = {"health": verify_health, "ownership": verify_ownership}[args.stage](
            client
        )
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
