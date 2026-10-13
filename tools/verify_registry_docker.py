"""Verify synthetic registry numbering, concurrency and lifecycle on an isolated stack."""

import argparse
import json
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import cv2
import httpx
import numpy as np
from verify_docker_upload import (
    compose_output,
    read_record,
    require,
    verify_file,
    verify_source,
)


def verify(args):
    require(args.project != "biolivestock", "Use a dedicated test stack, never collection data")
    require(not args.output.exists(), "Evidence file already exists")
    keys = json.loads(args.credentials_file.read_text("utf-8"))
    headers = {"Authorization": "Bearer " + keys["operator"]["token"]}
    root = args.url.rstrip("/") + "/api/v1/registry/animals"
    owner = {"owner_id": "SYNTHETIC-OWNER-1", "name": "Synthetic owner"}
    issuance = {"species": "cattle", "owner": owner}

    def post(path, body, key):
        return httpx.post(path, json=body, headers={**headers, "Idempotency-Key": key}, timeout=60)

    def query(sql):
        return compose_output(args.project, "exec", "-T", "db", "psql", "-U", "biolivestock", "-Atc", sql)

    sources = verify_source(args.project)
    configs = httpx.get(args.url + "/api/v1/species", headers=headers, timeout=30).json()
    numbering = next(item["numbering"] for item in configs if item["species"] == "cattle")
    pattern = re.compile(re.escape(numbering["prefix"]) + rf"[A-Z]{{{numbering.get('series_letters', 0)}}}[0-9]{{{numbering['digits']}}}")
    require(query("SELECT version_num FROM alembic_version") == "0005", "Registry migration missing")
    before = int(query("SELECT count(*) FROM captures"))
    with ThreadPoolExecutor(max_workers=8) as pool:
        allocations = list(pool.map(lambda _: post(root, issuance, uuid4().hex), range(8)))
    require(all(r.status_code == 201 for r in allocations), "Concurrent allocation failed")
    ids = [r.json()["animal_id"] for r in allocations]
    require(len(set(ids)) == 8 and all(pattern.fullmatch(i) for i in ids), "Numbers overlap or format differs")
    replay_key = uuid4().hex
    with ThreadPoolExecutor(max_workers=4) as pool:
        retries = list(pool.map(lambda _: post(root, issuance, replay_key), range(4)))
    require(all(r.status_code == 201 and r.json() == retries[0].json() for r in retries), "ID replay failed")
    animal = retries[0].json()
    route = root + "/cattle/" + animal["animal_id"]
    require(query(f"SELECT count(*) FROM registry_receipts WHERE request_key='{replay_key}'") == "1", "Replay duplicated receipts")
    observation = {"expected_version": 1, "observed_at": datetime.now(UTC).isoformat(),
                   "gps": {"latitude": 41.3, "longitude": 69.2}, "reason": "Synthetic verification"}
    with ThreadPoolExecutor(max_workers=2) as pool:
        transfers = list(pool.map(lambda n: post(route + "/owner", {**observation, "owner": {
            "owner_id": f"SYNTHETIC-OWNER-{n}", "name": "Synthetic transfer"}}, uuid4().hex), [2, 3]))
    require(sorted(r.status_code for r in transfers) == [200, 409], "Concurrent transfer did not protect version")
    current = next(r.json() for r in transfers if r.status_code == 200)
    metadata = {"animal_id": animal["animal_id"], "species": "cattle", "gps": observation["gps"],
                "timestamp": datetime.now(UTC).isoformat(), "operator_id": keys["operator"]["operator_id"]}
    content = cv2.imencode(".jpg", np.random.default_rng(42).integers(50, 201, (480, 640, 3), dtype=np.uint8))[1].tobytes()
    scan = httpx.post(args.url + "/api/v1/captures", headers={**headers, "Idempotency-Key": uuid4().hex},
                      data={"metadata": json.dumps(metadata)}, files={"image": ("synthetic.jpg", content, "image/jpeg")}, timeout=60)
    require(scan.status_code == 201 and scan.json()["crop_status"] == "pending_model", "Numbered upload failed")
    record = read_record(args.project, scan.json()["id"])
    file = verify_file(args.project, args.storage, record, (640, 480))
    terminal = {**observation, "expected_version": current["version"], "lifecycle": "slaughtered",
                "facility_id": "SYNTHETIC-ABATTOIR", "capture_id": scan.json()["id"]}
    terminal_key = uuid4().hex
    closed = post(route + "/retirement", terminal, terminal_key)
    require(closed.status_code == 200, "Slaughter report failed")
    require(post(route + "/retirement", terminal, terminal_key).json() == closed.json(), "Terminal replay differs")
    require(post(route + "/owner", {**observation, "expected_version": 3, "owner": owner}, uuid4().hex).status_code == 409, "Archived owner changed")
    check = httpx.get(route + "/slaughter-check", headers=headers, timeout=30).json()
    require(check["recorded_slaughter"] and not check["biometric_identity_verified"] and not check["independent_slaughter_verified"], "Report overclaims proof")
    require(check["animal"]["terminal_record"]["capture_stored_sha256"] == record["stored_sha256"], "Capture evidence lost")
    next_animal = post(root, issuance, uuid4().hex).json()
    require(next_animal["animal_id"] not in ids + [animal["animal_id"]], "Archived number recycled")
    require(httpx.get(root, params={"species": "cattle", "lifecycle": "slaughtered"}, headers=headers).status_code == 200, "Archived lookup failed")
    require(httpx.get(route).status_code == 401, "Unauthenticated registry disclosed")
    require(post(root, {**issuance, "species": "sheep"}, uuid4().hex).status_code == 422, "Disabled sheep accepted")
    # Each rejected SQL runs in its own transaction; successful BEGIN changes are rolled back.
    guarded = [
        "UPDATE animal_number_counters SET last_number=1 WHERE prefix='M'",
        f"UPDATE animal_profiles SET lifecycle='active' WHERE animal_id='{animal['animal_id']}'",
        f"DELETE FROM registry_receipts WHERE request_key='{replay_key}'",
    ]
    for sql in guarded:
        try:
            query("BEGIN; " + sql + "; ROLLBACK;")
        except subprocess.CalledProcessError as error:
            require("ERROR:" in error.stderr and (
                "Animal numbers must advance" in error.stderr
                or "Animal identity and archived history are retained" in error.stderr
                or "Evidence is append-only" in error.stderr
            ), "SQL guard failed for an unrelated reason")
        else:
            raise RuntimeError("Protected SQL unexpectedly succeeded")
    require(int(query("SELECT count(*) FROM captures")) == before + 1, "Existing captures changed")
    evidence = {"synthetic": True, "schema_revision": "0005", "source_hashes": sources,
                "concurrent_allocations": ids, "concurrent_retries": 4, "replay_animal": animal,
                "owner_race_statuses": [r.status_code for r in transfers], "terminal": closed.json(),
                "slaughter_check": check, "capture": scan.json(), "record": record, "file": file,
                "next_id": next_animal["animal_id"], "retained_prior_captures": before,
                "database_trigger_guards": len(guarded)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(evidence, stream, indent=2)
    print(f"Verified numbering/replay/ownership/terminal report and upload on PostgreSQL: {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://localhost:18001")
    parser.add_argument("--project", default="biolivestock-reliability")
    parser.add_argument("--credentials-file", type=Path, default=Path("backend/.secrets/tokens.json"))
    parser.add_argument("--storage", type=Path, default=Path("data/reliability"))
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args())
