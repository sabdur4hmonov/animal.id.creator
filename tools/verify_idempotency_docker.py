"""Keep synthetic evidence of simultaneous upload retries on PostgreSQL."""

import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import cv2
import httpx
import numpy as np
from verify_docker_upload import compose_output, read_record, require


def verify(args):
    keys = json.loads(args.credentials_file.read_text("utf-8"))
    key = uuid4().hex
    metadata = {
        "animal_id": f"RETRY-{key[:12]}",
        "species": "cattle",
        "gps": None,
        "timestamp": datetime.now(UTC).isoformat(),
        "operator_id": keys["operator"]["operator_id"],
    }
    image = np.random.default_rng(int(key[:8], 16)).integers(50, 201, (480, 640, 3), dtype=np.uint8)
    content = cv2.imencode(".jpg", image)[1].tobytes()

    def send(labels, token=keys["operator"]["token"]):
        return httpx.post(
            args.url + "/api/v1/captures",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": key},
            data={"metadata": json.dumps(labels)},
            files={"image": ("synthetic.jpg", content, "image/jpeg")},
            timeout=60,
        )

    with ThreadPoolExecutor(max_workers=4) as pool:
        responses = list(pool.map(lambda _: send(metadata), range(4)))
    require(all(response.status_code == 201 for response in responses), "Concurrent replay failed")
    saved = responses[0].json()
    require(all(response.json() == saved for response in responses), "Replay responses differ")
    require(saved["crop_status"] == "pending_model", "Unexpected crop status")
    require(send(metadata).json() == saved, "Later retry differs")
    changed = {**metadata, "animal_id": metadata["animal_id"] + "-CHANGED"}
    require(send(changed).status_code == 409, "Changed request not rejected")
    require(send(metadata, "invalid").status_code == 401, "Replay bypassed authentication")
    require(send(metadata, keys["admin"]["token"]).status_code == 403, "Replay bypassed operator binding")
    row = read_record(args.project, saved["id"])
    sql = f"SELECT count(*) FROM upload_receipts WHERE request_key='{key}';"
    count = compose_output(args.project, "exec", "-T", "db", "psql", "-U", "biolivestock", "-Atc", sql)
    require(count == "1", "Multiple receipts created")
    sql = f"SELECT count(*) FROM captures WHERE animal_id='{metadata['animal_id']}';"
    count = compose_output(args.project, "exec", "-T", "db", "psql", "-U", "biolivestock", "-Atc", sql)
    require(count == "1", "Multiple captures created")
    require((args.storage / row["file_path"]).is_file(), "Saved original missing")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump({"synthetic": True, "concurrent_retries": 4, "capture": saved, "record": row}, stream, indent=2)
    print(f"Verified four simultaneous retries, one PostgreSQL capture/receipt; evidence: {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://localhost:18001")
    parser.add_argument("--project", default="biolivestock-reliability")
    parser.add_argument("--credentials-file", type=Path, default=Path("backend/.secrets/tokens.json"))
    parser.add_argument("--storage", type=Path, default=Path("data/reliability"))
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args())
