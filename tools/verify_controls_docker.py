"""Exercise authenticated controls in the isolated Docker stack; retain synthetic evidence."""

import argparse
import json
import subprocess
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from uuid import UUID, uuid4

import cv2
import httpx
import numpy as np
from verify_docker_upload import ROOT, compose_output, require, upload


def check(response, status):
    require(
        response.status_code == status,
        f"Expected {status}, got {response.status_code}: {response.text}",
    )
    return response.json()


def verify(args):
    credentials = json.loads(args.credentials_file.read_text("utf-8"))
    operator, admin = credentials["operator"], credentials["admin"]
    admin_headers = {"Authorization": f"Bearer {admin['token']}"}
    # Random texture only exercises persistence and exact replay; it depicts no animal.
    image = np.random.default_rng(17).integers(50, 201, (480, 640, 3), dtype=np.uint8)
    content = cv2.imencode(".jpg", image)[1].tobytes()
    label = f"CONTROL-{uuid4().hex[:12]}"
    metadata = {
        "animal_id": label,
        "species": "cattle",
        "gps": {"latitude": 41, "longitude": 69},
        "timestamp": datetime.now(UTC).isoformat(),
        "operator_id": operator["operator_id"],
    }
    with httpx.Client(
        base_url=args.url,
        timeout=30,
        headers={"Authorization": f"Bearer {operator['token']}"},
    ) as client:
        check(client.get("/api/v1/species", headers={"Authorization": ""}), 401)
        check(client.get("/api/v1/admin/duplicates?species=cattle"), 403)
        check(
            upload(client, content, {**metadata, "operator_id": "forged-operator"}), 403
        )
        first = check(upload(client, content, metadata), 201)
        second = check(
            upload(client, content, {**metadata, "animal_id": label + "-COPY"}), 201
        )
        require(
            second["duplicate_summary"]["exact_image_matches"] >= 1,
            "Exact reuse flag missing",
        )
        animal = check(client.get(f"/api/v1/animals/cattle/{label}"), 200)
        check(
            client.post(
                "/api/v1/animals", json={"species": "cattle", "animal_id": label}
            ),
            409,
        )
        status = {
            "status": "insured",
            "expected_version": animal["version"],
            "reason": "Synthetic policy",
        }
        route = f"/api/v1/animals/cattle/{label}/status"
        check(client.patch(route, json=status), 403)
        insured = check(client.patch(route, json=status, headers=admin_headers), 200)
        check(client.patch(route, json=status, headers=admin_headers), 409)
        cases = check(
            client.get(
                "/api/v1/admin/duplicates?species=cattle&limit=200",
                headers=admin_headers,
            ),
            200,
        )
        case = next(
            case
            for case in cases
            if case["capture_id"] == second["id"]
            and case["matched_capture_id"] == first["id"]
        )
        reviewed = check(
            client.patch(
                f"/api/v1/admin/duplicates/{case['id']}",
                headers=admin_headers,
                json={
                    "state": "confirmed",
                    "expected_version": case["version"],
                    "note": "Synthetic exact replay verified",
                },
            ),
            200,
        )
        require(
            reviewed["reviewed_by"] == admin["operator_id"], "Review principal mismatch"
        )
        capture_id = str(UUID(first["id"]))
        try:
            compose_output(
                args.project,
                "exec",
                "-T",
                "db",
                "psql",
                "-U",
                "biolivestock",
                "-d",
                "biolivestock",
                "-v",
                "ON_ERROR_STOP=1",
                "-c",
                f"UPDATE captures SET operator_id='tampered' WHERE id='{capture_id}';",
            )
        except subprocess.CalledProcessError as exc:
            require("append-only" in exc.stderr, "Update failed for unexpected reason")
        else:
            raise RuntimeError("PostgreSQL allowed scan mutation")
        after = check(client.get(f"/api/v1/captures/{capture_id}"), 200)
        require(
            after["operator_id"] == operator["operator_id"]
            and after["gps"] == metadata["gps"],
            "Immutable provenance changed",
        )
        current = client.get("/api/v1/market-rates/cattle?currency=UZS")
        require(current.status_code in (200, 404), "Market lookup failed")
        quote = {
            "species": "cattle",
            "currency": "UZS",
            "basis": "carcass",
            "price_per_kg": "100",
            "observed_at": datetime.now(UTC).isoformat(),
            "source": "Synthetic Docker verification",
            "expected_latest_id": current.json()["id"]
            if current.status_code == 200
            else None,
        }
        check(client.post("/api/v1/admin/market-rates", json=quote), 403)
        rate = check(
            client.post(
                "/api/v1/admin/market-rates", json=quote, headers=admin_headers
            ),
            201,
        )
        check(
            client.post(
                "/api/v1/admin/market-rates", json=quote, headers=admin_headers
            ),
            409,
        )
        estimate = {
            "species": "cattle",
            "method": "trukhanovsky",
            "adult": True,
            "breed_category": "dairy",
            "chest_girth_cm": "180",
            "body_length_cm": "150",
            "currency": "UZS",
        }
        valuation = check(client.post("/api/v1/valuation", json=estimate), 200)
        require(
            Decimal(valuation["measurements"]["live_weight_kg"]) == 540,
            "Formula math mismatch",
        )
        require(
            valuation["carcass_value_range"] == ["27000.00", "31320.00"],
            "Valuation math mismatch",
        )
        require(valuation["market_rate_id"] == rate["id"], "Market provenance mismatch")
        check(
            client.post("/api/v1/valuation", json={**estimate, "species": "sheep"}), 422
        )
    output = ROOT / "data" / "verification" / "evidence" / f"controls-{uuid4()}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "verified_at": datetime.now(UTC).isoformat(),
        "synthetic_input": True,
        "unauthenticated_status": 401,
        "operator_admin_status": 403,
        "forged_operator_status": 403,
        "registration_conflict_status": 409,
        "stale_status_edit": 409,
        "postgresql_mutation_rejected": True,
        "captures": [first, second],
        "insured_registration": insured,
        "review": reviewed,
        "synthetic_market_rate": rate,
        "synthetic_valuation": valuation,
    }
    with output.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2, allow_nan=False)
        stream.write("\n")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--credentials-file",
        type=Path,
        default=ROOT / "backend" / ".secrets" / "tokens.json",
    )
    parser.add_argument("--project", default="biolivestock-verification")
    parser.add_argument("--url", default="http://127.0.0.1:18000")
    print(f"Verified Docker controls; evidence: {verify(parser.parse_args())}")


if __name__ == "__main__":
    main()
