"""Exercise letter-series boundaries only in a dedicated fresh synthetic stack."""

import argparse
import json
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

BLOCK = 99_999_999
MAXIMUM = 676 * BLOCK


def verify(args):
    require(args.project.startswith("biolivestock-numbering"), "Use a dedicated numbering test stack")
    require(not args.output.exists(), "Never overwrite prior evidence")
    keys = json.loads(args.credentials_file.read_text("utf-8"))
    headers = {"Authorization": "Bearer " + keys["operator"]["token"]}
    root = args.url.rstrip("/") + "/api/v1/registry/animals"
    body = {"species": "cattle", "owner": {"owner_id": "SYNTHETIC-NUMBERING", "name": "Synthetic test"}}

    def query(sql):
        return compose_output(args.project, "exec", "-T", "db", "psql", "-U", "biolivestock", "-Atc", sql)

    def post(key):
        return httpx.post(root, json=body, headers={**headers, "Idempotency-Key": key}, timeout=60)

    source = verify_source(args.project)
    require(query("SELECT count(*) FROM animals") == "0", "Boundary seeding requires a fresh empty test database")
    require(query("SELECT count(*) FROM animal_number_counters") == "0", "Counter already exists; use a fresh test stack")
    first_key = uuid4().hex
    first = post(first_key)
    require(first.status_code == 201 and first.json()["animal_id"] == "MAA00000001", "Fresh numbering differs")
    metadata = {"animal_id": first.json()["animal_id"], "species": "cattle", "gps": None,
                "timestamp": datetime.now(UTC).isoformat(), "operator_id": keys["operator"]["operator_id"]}
    content = cv2.imencode(".jpg", np.random.default_rng(43).integers(50, 201, (480, 640, 3), dtype=np.uint8))[1].tobytes()
    scan = httpx.post(args.url + "/api/v1/captures", headers={**headers, "Idempotency-Key": uuid4().hex},
                      data={"metadata": json.dumps(metadata)}, files={"image": ("synthetic.jpg", content, "image/jpeg")}, timeout=60)
    require(scan.status_code == 201 and scan.json()["crop_status"] == "pending_model", "Series upload failed")
    record = read_record(args.project, scan.json()["id"])
    file = verify_file(args.project, args.storage, record, (640, 480))
    boundaries = []
    for block_count, ending, following in [(1, "MAA", "MAB"), (26, "MAZ", "MBA")]:
        seed = block_count * BLOCK - 3
        query(f"UPDATE animal_number_counters SET last_number={seed} WHERE prefix='M'")
        with ThreadPoolExecutor(max_workers=8) as pool:
            responses = list(pool.map(lambda _: post(uuid4().hex), range(8)))
        require(all(r.status_code == 201 for r in responses), "Boundary concurrent allocation failed")
        ids = sorted(r.json()["animal_id"] for r in responses)
        expected = sorted([f"{ending}{n:08d}" for n in range(BLOCK - 2, BLOCK + 1)]
                          + [f"{following}{n:08d}" for n in range(1, 6)])
        require(ids == expected and all(len(i) == 11 for i in ids), "Boundary numbers overlap, grow or skip unexpectedly")
        require(query("SELECT last_number FROM animal_number_counters WHERE prefix='M'") == str(seed + 8), "Counter reset at rollover")
        retry_key = uuid4().hex
        with ThreadPoolExecutor(max_workers=4) as pool:
            replay = list(pool.map(lambda _, key=retry_key: post(key), range(4)))
        require(all(r.status_code == 201 and r.json() == replay[0].json() for r in replay), "Concurrent replay differs")
        require(query(f"SELECT count(*) FROM registry_receipts WHERE request_key='{retry_key}'") == "1", "Duplicate replay receipt")
        boundaries.append({"seed": seed, "parallel_ids": ids, "concurrent_replay_id": replay[0].json()["animal_id"]})
    query(f"UPDATE animal_number_counters SET last_number={MAXIMUM - 1} WHERE prefix='M'")
    final_key = uuid4().hex
    final = post(final_key)
    require(final.status_code == 201 and final.json()["animal_id"] == "MZZ99999999", "Last ID differs")
    exhausted_key = uuid4().hex
    require(post(exhausted_key).status_code == 503, "Exhaustion wraps or creates an ID")
    require(query(f"SELECT count(*) FROM registry_receipts WHERE request_key='{exhausted_key}'") == "0", "Exhaustion acknowledged as accepted")
    require(query("SELECT last_number FROM animal_number_counters WHERE prefix='M'") == str(MAXIMUM), "Exhaustion reset counter")
    require(post(first_key).json() == first.json() and post(final_key).json() == final.json(), "Stored receipts changed after exhaustion")
    evidence = {"synthetic": True, "project": args.project, "schema_revision": query("SELECT version_num FROM alembic_version"),
                "source_hashes": source, "boundaries": boundaries, "first": first.json(), "final": final.json(),
                "exhaustion_status": 503, "final_counter": MAXIMUM, "capture": scan.json(), "record": record, "file": file}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(evidence, stream, indent=2)
    print(f"Verified parallel AA/AB and AZ/BA rollover, stable width, final exhaustion/replay and upload: {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://localhost:18002")
    parser.add_argument("--project", default="biolivestock-numbering")
    parser.add_argument("--credentials-file", type=Path, default=Path("backend/.secrets/tokens.json"))
    parser.add_argument("--storage", type=Path, default=Path("data/numbering"))
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args())
