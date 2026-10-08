import hashlib
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security_config import SecurityConfig
from app.core.settings import Settings
from app.core.species import SpeciesConfig
from app.models.capture import Capture
from app.models.upload_receipt import UploadReceipt
from app.schemas.capture import CaptureMetadata, CaptureResponse
from app.services.anti_spoofing import scan_risk
from app.services.detection import NoseDetector
from app.services.idempotency import lock_request, replay, request_digest
from app.services.quality_control import check_quality
from app.services.registration import duplicate_candidates, ensure_animal, flag_duplicates
from app.services.storage import decode_image, write_image


class QualityRejected(Exception):
    def __init__(self, stage, quality):
        self.stage = stage
        self.quality = quality


def collect_capture(
    content: bytes,
    metadata: CaptureMetadata,
    config: SpeciesConfig,
    detector: NoseDetector,
    settings: Settings,
    session: Session,
    security_config: SecurityConfig,
    request_key: str | None = None,
) -> Capture | dict:
    digest = request_digest(content, metadata) if request_key else None
    if request_key:
        lock_request(session, metadata.operator_id, request_key)
        previous_response = replay(session, metadata.operator_id, request_key, digest)
        if previous_response is not None:
            return previous_response
    image = decode_image(content, settings.max_image_pixels)
    quality = check_quality(image, config.quality)
    if not quality.passed:
        raise QualityRejected("original", quality)
    result = detector.detect(image, config)
    crop_quality = None
    if result is not None:
        crop_config = config.quality.model_copy(
            update={
                "min_width": config.crop.min_width,
                "min_height": config.crop.min_height,
            }
        )
        crop_quality = check_quality(result.crop, crop_config)
        if not crop_quality.passed:
            raise QualityRejected("crop", crop_quality)
    capture_id = str(uuid4())
    paths = []
    try:
        received_at = datetime.now(UTC)
        fingerprint = hashlib.sha256(str(image.shape).encode() + image.tobytes()).hexdigest()
        matches = duplicate_candidates(session, metadata.species, fingerprint)
        ensure_animal(session, metadata)
        previous = session.scalar(
            select(Capture)
            .where(
                Capture.species == metadata.species,
                Capture.operator_id == metadata.operator_id,
                Capture.received_at.is_not(None),
            )
            .order_by(Capture.received_at.desc(), Capture.id.desc())
            .limit(1)
        )
        risk = scan_risk(image, metadata, received_at, security_config, previous)
        original_path = write_image(settings.storage_root, metadata, capture_id, "original", image)
        paths.append(original_path)
        crop_path = None
        if result is not None:
            crop_path = write_image(settings.storage_root, metadata, capture_id, "muzzle", result.crop)
            paths.append(crop_path)
        record = Capture(
            id=capture_id,
            animal_id=metadata.animal_id,
            species=metadata.species,
            gps=metadata.gps.model_dump() if metadata.gps else None,
            timestamp=metadata.timestamp.astimezone(UTC),
            operator_id=metadata.operator_id,
            image_quality_score=quality.score,
            file_path=original_path,
            crop_path=crop_path,
            crop_status="cropped" if result is not None else "pending_model",
            quality=quality.model_dump(),
            crop_quality=crop_quality.model_dump() if crop_quality else None,
            detection=result.metadata if result is not None else None,
            config_version=config.config_version,
            config_snapshot=config.model_dump(mode="json"),
            received_at=received_at,
            risk_signals=risk,
            source_sha256=hashlib.sha256(content).hexdigest(),
            pixel_sha256=fingerprint,
            stored_sha256=hashlib.sha256((settings.storage_root / original_path).read_bytes()).hexdigest(),
            duplicate_summary={
                "exact_image_matches": len(matches[:100]),
                "truncated": len(matches) > 100,
                "biometric_identity_checked": False,
            },
        )
        session.add(record)
        session.flush()
        flag_duplicates(session, record, matches)
        if request_key:
            session.add(
                UploadReceipt(
                    operator_id=metadata.operator_id,
                    request_key=request_key,
                    payload_sha256=digest,
                    capture_id=record.id,
                    response=CaptureResponse.model_validate(record, from_attributes=True).model_dump(mode="json"),
                )
            )
        session.commit()
        return record
    except Exception:
        session.rollback()
        for path in paths:
            (settings.storage_root / path).unlink(missing_ok=True)
        raise
