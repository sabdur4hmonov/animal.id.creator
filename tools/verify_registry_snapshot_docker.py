"""Verify coherent registry reads while synthetic owner changes commit concurrently."""

import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from pathlib import Path
from threading import Barrier
from uuid import uuid4

import httpx
from verify_docker_upload import require, verify_source


def verify(args):
    require(
        args.project == "biolivestock-reliability",
        "Use the retained synthetic reliability stack",
    )
    require(not args.output.exists(), "Never overwrite verification evidence")
    keys = json.loads(args.credentials_file.read_text("utf-8"))
    headers = {"Authorization": "Bearer " + keys["operator"]["token"]}
    root = args.url.rstrip("/") + "/api/v1/registry/animals"
    source = verify_source(args.project)
    first = httpx.post(
        root,
        headers={**headers, "Idempotency-Key": uuid4().hex},
        json={
            "species": "cattle",
            "owner": {"owner_id": "SNAPSHOT-1", "name": "Synthetic owner"},
        },
        timeout=30,
    )
    require(first.status_code == 201, "Synthetic registration failed")
    route = root + "/cattle/" + first.json()["animal_id"]
    ready = Barrier(3)

    def write():
        with httpx.Client(headers=headers, timeout=30) as client:
            ready.wait(timeout=20)
            for version in range(1, 31):
                result = client.post(
                    route + "/owner",
                    headers={"Idempotency-Key": uuid4().hex},
                    json={
                        "expected_version": version,
                        "owner": {
                            "owner_id": f"SNAPSHOT-{version + 1}",
                            "name": "Synthetic owner",
                        },
                        "observed_at": datetime.now(UTC).isoformat(),
                        "gps": None,
                        "reason": "Synthetic snapshot race",
                    },
                )
                require(result.status_code == 200, "Concurrent owner update failed")

    def read():
        versions = []
        with httpx.Client(headers=headers, timeout=30) as client:
            ready.wait(timeout=20)
            for _ in range(100):
                response = client.get(route + "/slaughter-check")
                require(response.status_code == 200, "Registry read failed")
                value = response.json()
                animal = value["animal"]
                require(
                    animal["owner"]["owner_id"] == f"SNAPSHOT-{animal['version']}",
                    "Torn owner/version snapshot",
                )
                require(
                    animal["lifecycle"] == "active"
                    and animal["terminal_record"] is None
                    and not value["recorded_slaughter"],
                    "Unexpected terminal state",
                )
                versions.append(animal["version"])
        return versions

    with ThreadPoolExecutor(max_workers=3) as pool:
        writer = pool.submit(write)
        readers = [pool.submit(read), pool.submit(read)]
        writer.result()
        observed = [future.result() for future in readers]
    require(any(version < 31 for versions in observed for version in versions), "Readers did not overlap owner updates")
    final = httpx.get(route + "/slaughter-check", headers=headers, timeout=30).json()
    require(
        final["animal"]["version"] == 31
        and final["animal"]["owner"]["owner_id"] == "SNAPSHOT-31",
        "Final owner differs",
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(
            {
                "synthetic": True,
                "source_hashes": source,
                "animal_id": first.json()["animal_id"],
                "owner_updates": 30,
                "concurrent_reads": observed,
                "final": final,
            },
            stream,
            indent=2,
        )
    print(
        f"Verified 200 registry reads during 30 owner updates with no torn owner/version: {args.output}"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://localhost:18001")
    parser.add_argument("--project", default="biolivestock-reliability")
    parser.add_argument(
        "--credentials-file", type=Path, default=Path("backend/.secrets/tokens.json")
    )
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args())
