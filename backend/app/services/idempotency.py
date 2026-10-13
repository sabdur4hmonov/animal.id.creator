import hashlib
import json
from datetime import UTC

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.upload_receipt import UploadReceipt
from app.schemas.capture import CaptureMetadata
from app.services.integrity import require_saved_files


class UploadConflict(Exception):
    pass


def request_digest(content: bytes, metadata: CaptureMetadata) -> str:
    values = metadata.model_dump(mode="json")
    values["timestamp"] = metadata.timestamp.astimezone(UTC).isoformat()
    canonical = json.dumps(values, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    return hashlib.sha256(canonical + b"\0" + hashlib.sha256(content).digest()).hexdigest()


def lock_request(session: Session, operator_id: str, key: str) -> None:
    if session.get_bind().dialect.name == "postgresql":
        digest = hashlib.sha256(f"upload:{operator_id}:{key}".encode()).digest()
        session.execute(
            text("SELECT pg_advisory_xact_lock(:key)"),
            {"key": int.from_bytes(digest[:8], "big", signed=True)},
        )


def replay(session: Session, operator_id: str, key: str, digest: str, storage_root) -> dict | None:
    receipt = session.get(UploadReceipt, (operator_id, key))
    if receipt is None:
        return None
    if receipt.payload_sha256 != digest:
        raise UploadConflict("Idempotency key was already used with different image or metadata")
    require_saved_files(storage_root, receipt.response)
    return receipt.response
