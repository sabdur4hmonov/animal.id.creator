"""Verify an isolated Docker/PostgreSQL upload; preserve its sample and evidence."""

import argparse
import hashlib
import json
import subprocess
from datetime import UTC, datetime
from io import BytesIO
from pathlib import Path
from uuid import UUID, uuid4

import httpx
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "backend" / "docker-compose.yml"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def compose_output(project, *args):
    result = subprocess.run(
        ["docker", "compose", "-p", project, "-f", str(COMPOSE), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
        timeout=60,
    )
    return result.stdout.strip()


def read_record(project, capture_id):
    capture_id = str(UUID(capture_id))
    sql = f"SELECT row_to_json(c) FROM captures c WHERE id = '{capture_id}';"
    return json.loads(
        compose_output(
            project,
            "exec",
            "-T",
            "db",
            "psql",
            "-U",
            "biolivestock",
            "-d",
            "biolivestock",
            "-At",
            "-c",
            sql,
        )
    )


def verify_source(project):
    files = [
        "app/api/routes.py",
        "app/services/quality_control.py",
        "app/core/species.py",
    ]
    code = "import hashlib,json,pathlib,sys; print(json.dumps({p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest() for p in sys.argv[1:]}))"
    remote = json.loads(
        compose_output(project, "exec", "-T", "api", "python", "-c", code, *files)
    )
    local = {
        name: hashlib.sha256((ROOT / "backend" / name).read_bytes()).hexdigest()
        for name in files
    }
    require(
        remote == local, "Docker backend differs from current source; rebuild it first"
    )
    return remote


def verify_file(project, storage, record, expected_size):
    relative = Path(record["file_path"])
    path = (storage / relative).resolve()
    require(
        path.is_relative_to(storage.resolve()),
        "Saved path escapes verification storage",
    )
    with Image.open(path) as saved:
        require(
            saved.format == "JPEG" and saved.size == expected_size,
            "Saved JPEG dimensions/format differ",
        )
        saved.load()
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    code = "import hashlib,pathlib,sys; print(hashlib.sha256((pathlib.Path('/srv/data')/sys.argv[1]).read_bytes()).hexdigest())"
    remote = compose_output(
        project, "exec", "-T", "api", "python", "-c", code, relative.as_posix()
    )
    require(remote == digest, "Container and host image hashes differ")
    return {"path": str(path), "sha256": digest, "size_bytes": path.stat().st_size}


def upload(client, content, metadata):
    return client.post(
        "/api/v1/captures",
        data={"metadata": json.dumps(metadata)},
        files={"image": ("verification.jpg", content, "image/jpeg")},
    )


def verify_rejections(client, content, metadata, project, storage, record):
    flat = BytesIO()
    Image.new("RGB", (640, 480), (128, 128, 128)).save(flat, format="JPEG")
    blur = upload(client, flat.getvalue(), metadata)
    require(blur.status_code == 422, f"Blurred image was not rejected: {blur.text}")
    require(
        "blurry" in blur.json()["detail"]["quality"]["reasons"],
        "Blur rejection reason missing",
    )
    invalid = {**metadata, "gps": {"latitude": float("nan"), "longitude": 0}}
    gps = upload(client, content, invalid)
    require(gps.status_code == 422, f"Invalid GPS did not return 422: {gps.text}")
    # The generated animal ID contains only ASCII letters, digits and hyphens.
    sql = f"SELECT count(*) FROM captures WHERE animal_id = '{metadata['animal_id']}';"
    count = compose_output(
        project,
        "exec",
        "-T",
        "db",
        "psql",
        "-U",
        "biolivestock",
        "-d",
        "biolivestock",
        "-At",
        "-c",
        sql,
    )
    require(count == "1", "Rejected uploads left extra PostgreSQL records")
    directory = (storage / record["file_path"]).parent
    require(
        len(list(directory.glob("*.jpg"))) == 1,
        "Rejected uploads left extra image files",
    )
    return {
        "blur_http_status": blur.status_code,
        "invalid_gps_http_status": gps.status_code,
        "record_count": int(count),
    }


def verify(args):
    source_hashes = verify_source(args.project)
    content = args.image.read_bytes()
    with Image.open(BytesIO(content)) as image:
        require(image.format == "JPEG", "Verification input must be a real JPEG file")
        expected_size = ImageOps.exif_transpose(image).size
    metadata = {
        "animal_id": f"VERIFY-{uuid4().hex[:16]}",
        "species": "cattle",
        "gps": None,
        "timestamp": datetime.now(UTC).isoformat(),
        "operator_id": "backend-verification",
    }
    with httpx.Client(base_url=args.url, timeout=30) as client:
        health = client.get("/health")
        require(health.status_code == 200, f"Health failed: {health.text}")
        require(
            health.json()["models"]["cattle"] == "pending_model",
            "Verification expects no cattle weights",
        )
        configs = {
            item["species"]: item for item in client.get("/api/v1/species").json()
        }
        require(
            configs["cattle"]["enabled"] and not configs["sheep"]["enabled"],
            "Unexpected species settings",
        )
        response = upload(client, content, metadata)
        require(response.status_code == 201, f"Upload failed: {response.text}")
        result = response.json()
        require(result["quality"]["passed"], "Server QC did not pass")
        require(
            result["crop_status"] == "pending_model" and result["crop_path"] is None,
            "Unexpected crop status",
        )
        record = read_record(args.project, result["id"])
        for key in ("animal_id", "species", "gps", "operator_id"):
            require(record[key] == metadata[key], f"PostgreSQL {key} mismatch")
        for key in (
            "file_path",
            "crop_path",
            "crop_status",
            "image_quality_score",
            "quality",
            "config_version",
        ):
            require(record[key] == result[key], f"Response/PostgreSQL {key} mismatch")
        require(
            datetime.fromisoformat(record["timestamp"])
            == datetime.fromisoformat(metadata["timestamp"]),
            "Timestamp mismatch",
        )
        require(
            record["config_snapshot"] == configs["cattle"],
            "Species provenance mismatch",
        )
        require(
            record["crop_quality"] is None and record["detection"] is None,
            "Pending record contains crop data",
        )
        saved = verify_file(args.project, args.storage, record, expected_size)
        rejection_results = verify_rejections(
            client, content, metadata, args.project, args.storage, record
        )
    report = {
        "verified_at": datetime.now(UTC).isoformat(),
        "project": args.project,
        "url": args.url,
        "input_image": str(args.image.resolve()),
        "input_source": args.image_source,
        "input_sha256": hashlib.sha256(content).hexdigest(),
        "backend_source_sha256": source_hashes,
        "health": health.json(),
        "upload_http_status": response.status_code,
        "response": result,
        "postgresql_record": record,
        "stored_image": saved,
        "rejections": rejection_results,
    }
    output = args.storage / "evidence" / f"{result['id']}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8"
    )
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--image-source", default="locally supplied verification image")
    parser.add_argument("--project", default="biolivestock-verification")
    parser.add_argument("--url", default="http://127.0.0.1:18000")
    parser.add_argument("--storage", type=Path, default=ROOT / "data" / "verification")
    args = parser.parse_args()
    print(f"Verified Docker/PostgreSQL upload; evidence: {verify(args)}")


if __name__ == "__main__":
    main()
