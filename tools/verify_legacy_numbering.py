"""Compare retained numeric M IDs with the pre-series isolated backup and replay one receipt."""

import argparse
import hashlib
import json
from pathlib import Path

import httpx
from verify_docker_upload import compose_output, require


def verify(args):
    require(args.project == "biolivestock-reliability", "Use the retained synthetic registry test stack")
    require(args.previous_database.startswith("biolivestock_restore_"), "Comparison requires a restore clone")
    keys = json.loads(args.credentials_file.read_text("utf-8"))
    tables = ["animals", "animal_profiles", "audit_events", "captures", "registry_receipts"]
    evidence = {}

    def query(database, sql):
        return compose_output(args.project, "exec", "-T", "db", "psql", "-U", "biolivestock", "-d", database, "-Atc", sql)

    for table in tables:
        field = "response->>'animal_id'" if table == "registry_receipts" else "animal_id"
        snapshots = []
        for database in ["biolivestock", args.previous_database]:
            raw = query(database, f"SELECT row_to_json(t) FROM {table} t WHERE ({field}) ~ '^M[0-9]{{8}}$'")
            snapshots.append(sorted(json.dumps(json.loads(line), sort_keys=True) for line in raw.splitlines()))
        require(snapshots[0] == snapshots[1] and snapshots[0], f"Legacy {table} changed or missing")
        evidence[table] = {"rows": len(snapshots[0]), "sha256": hashlib.sha256("\n".join(snapshots[0]).encode()).hexdigest()}
    receipts = [json.loads(row) for row in query("biolivestock", "SELECT row_to_json(r) FROM registry_receipts r WHERE (response->>'animal_id') ~ '^M[0-9]{8}$' AND response->>'version'='1'").splitlines()]
    receipt = next(r for r in receipts if r["operator_id"] == keys["operator"]["operator_id"])
    response = receipt["response"]
    replay = httpx.post(args.url + "/api/v1/registry/animals",
                        json={"species": response["species"], "owner": response["owner"]},
                        headers={"Authorization": "Bearer " + keys["operator"]["token"], "Idempotency-Key": receipt["request_key"]}, timeout=30)
    require(replay.status_code == 201 and replay.json() == response, "Old acknowledgement changed under series config")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump({"synthetic": True, "equal_legacy_tables": evidence, "replayed_legacy_id": response["animal_id"]}, stream, indent=2)
    print(f"Verified all retained numeric M identities/evidence unchanged and old receipt replayed: {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="biolivestock-reliability")
    parser.add_argument("--url", default="http://localhost:18001")
    parser.add_argument("--previous-database", default="biolivestock_restore_registry_20261013")
    parser.add_argument("--credentials-file", type=Path, default=Path("backend/.secrets/tokens.json"))
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args())
