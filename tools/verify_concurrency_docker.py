"""Exercise PostgreSQL fingerprint and optimistic-edit races with synthetic input."""

import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import cv2
import httpx
import numpy as np
from verify_docker_upload import ROOT, require, upload


def verify(args):
    keys = json.loads(args.credentials_file.read_text("utf-8"))
    label = f"RACE-{uuid4().hex[:12]}"
    image = np.random.default_rng(int(uuid4().hex[:8], 16)).integers(
        50, 201, (480, 640, 3), dtype=np.uint8
    )
    content = cv2.imencode(".jpg", image)[1].tobytes()

    def scan(index):
        metadata = {
            "animal_id": f"{label}-{index}",
            "species": "cattle",
            "gps": None,
            "timestamp": datetime.now(UTC).isoformat(),
            "operator_id": keys["operator"]["operator_id"],
        }
        with httpx.Client(
            base_url=args.url,
            timeout=60,
            headers={"Authorization": f"Bearer {keys['operator']['token']}"},
        ) as client:
            response = upload(client, content, metadata)
            require(
                response.status_code == 201,
                f"Concurrent upload failed: {response.text}",
            )
            return response.json()

    with ThreadPoolExecutor(max_workers=2) as pool:
        captures = list(pool.map(scan, (0, 1)))
    matches = sorted(
        capture["duplicate_summary"]["exact_image_matches"] for capture in captures
    )
    require(
        matches == [0, 1], "Concurrent exact-image reuse was missed or inconsistent"
    )
    admin_headers = {"Authorization": f"Bearer {keys['admin']['token']}"}

    def status_edit(status):
        with httpx.Client(
            base_url=args.url, timeout=60, headers=admin_headers
        ) as client:
            response = client.patch(
                f"/api/v1/animals/cattle/{label}-0/status",
                json={
                    "status": status,
                    "expected_version": 1,
                    "reason": "Synthetic race",
                },
            )
            return response.status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        statuses = sorted(pool.map(status_edit, ("insured", "collateral")))
    require(
        statuses == [200, 409],
        "Concurrent status update lost optimistic-edit protection",
    )
    with httpx.Client(base_url=args.url, timeout=60, headers=admin_headers) as client:
        current = client.get("/api/v1/market-rates/cattle?currency=UZS")
        require(current.status_code in (200, 404), "Market lookup failed")
        expected = current.json()["id"] if current.status_code == 200 else None
        integrity = client.get(f"/api/v1/admin/captures/{captures[0]['id']}/integrity")
        require(
            integrity.status_code == 200 and integrity.json()["status"] == "matched",
            "Admin stored-image integrity check failed",
        )

    def price_edit(price):
        with httpx.Client(
            base_url=args.url, timeout=60, headers=admin_headers
        ) as client:
            response = client.post(
                "/api/v1/admin/market-rates",
                json={
                    "species": "cattle",
                    "currency": "UZS",
                    "basis": "carcass",
                    "price_per_kg": price,
                    "observed_at": datetime.now(UTC).isoformat(),
                    "source": "Synthetic concurrency test",
                    "expected_latest_id": expected,
                },
            )
            return response.status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        prices = sorted(pool.map(price_edit, ("101", "102")))
    require(
        prices == [201, 409], "Concurrent market update lost quote-version protection"
    )
    output = ROOT / "data" / "verification" / "evidence" / f"concurrency-{uuid4()}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as stream:
        json.dump(
            {
                "verified_at": datetime.now(UTC).isoformat(),
                "synthetic_input": True,
                "capture_ids": [capture["id"] for capture in captures],
                "exact_match_counts": matches,
                "status_edit_statuses": statuses,
                "market_edit_statuses": prices,
                "integrity": integrity.json(),
            },
            stream,
            indent=2,
            allow_nan=False,
        )
        stream.write("\n")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--credentials-file",
        type=Path,
        default=ROOT / "backend" / ".secrets" / "tokens.json",
    )
    parser.add_argument("--url", default="http://127.0.0.1:18000")
    print(f"Verified concurrent controls; evidence: {verify(parser.parse_args())}")


if __name__ == "__main__":
    main()
