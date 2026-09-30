from datetime import UTC
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.settings import Settings
from app.core.species import SpeciesConfig
from app.models.capture import Capture
from app.schemas.capture import CaptureMetadata
from app.services.detection import NoseDetector
from app.services.quality_control import check_quality
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
) -> Capture:
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
        )
        session.add(record)
        session.commit()
        return record
    except Exception:
        session.rollback()
        for path in paths:
            (settings.storage_root / path).unlink(missing_ok=True)
        raise
