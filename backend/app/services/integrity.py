import hashlib
from datetime import UTC, datetime
from types import SimpleNamespace


def require_saved_files(root, response):
    """Do not replay a successful receipt when its retained evidence is unavailable."""
    record = SimpleNamespace(
        id=response["id"], file_path=response["file_path"], stored_sha256=response.get("stored_sha256")
    )
    if verify_stored_image(root, record)["status"] != "matched":
        raise OSError("Saved original is missing, changed or unverifiable; restore evidence before retrying")
    if response.get("crop_status") == "cropped":
        relative = response.get("crop_path")
        if not relative:
            raise OSError("Saved crop path is unavailable")
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file():
            raise OSError("Saved crop is unavailable")


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
