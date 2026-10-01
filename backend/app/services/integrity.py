import hashlib
from datetime import UTC, datetime


def verify_stored_image(root, record):
    result = {
        "capture_id": record.id,
        "checked_at": datetime.now(UTC),
        "expected_sha256": record.stored_sha256,
        "actual_sha256": None,
        "metadata_database_policy": "append_only",
        "external_attestation": False,
    }
    if not record.stored_sha256:
        return {**result, "status": "unavailable_legacy"}
    path = (root / record.file_path).resolve()
    if not path.is_relative_to(root.resolve()):
        return {**result, "status": "unsafe_path"}
    try:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        actual = digest.hexdigest()
        return {
            **result,
            "actual_sha256": actual,
            "status": "matched" if actual == record.stored_sha256 else "mismatch",
        }
    except FileNotFoundError:
        return {**result, "status": "missing"}
