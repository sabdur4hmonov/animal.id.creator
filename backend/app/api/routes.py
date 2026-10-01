import logging
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from pydantic import ValidationError
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.database import get_session
from app.schemas.capture import CaptureMetadata, CaptureResponse
from app.services.collection import QualityRejected, collect_capture
from app.services.detection import DetectionUnavailable, FramingError

router = APIRouter()
logger = logging.getLogger(__name__)
SessionDep = Annotated[Session, Depends(get_session)]


@router.get("/health")
def health(request: Request, session: SessionDep):
    try:
        session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(503, "Database unavailable") from exc
    detector = request.app.state.detector
    return {
        "status": "ok",
        "database": "ok",
        "models": {
            key.value: ("checkpoint_present" if detector.checkpoint(config).is_file() else "pending_model")
            for key, config in request.app.state.species_configs.items()
            if config.enabled
        },
    }


@router.get("/api/v1/species")
def species_configs(request: Request):
    # The app obtains its quality rules here, so sheep needs no new UI branch.
    return [config.model_dump(mode="json") for config in request.app.state.species_configs.values()]


@router.post("/api/v1/captures", response_model=CaptureResponse, status_code=201)
def upload_capture(
    request: Request,
    session: SessionDep,
    image: Annotated[UploadFile, File()],
    metadata: Annotated[str, Form()],
):
    try:
        parsed = CaptureMetadata.model_validate_json(metadata)
    except ValidationError as exc:
        # Echoing invalid inputs such as NaN would break JSON error serialization.
        raise HTTPException(422, exc.errors(include_context=False, include_input=False)) from exc
    config = request.app.state.species_configs[parsed.species]
    if not config.enabled:
        raise HTTPException(422, "This species is disabled")
    settings = request.app.state.settings
    try:
        content = image.file.read(settings.max_upload_bytes + 1)
    finally:
        image.file.close()
    if len(content) > settings.max_upload_bytes:
        raise HTTPException(413, "Image exceeds upload limit")
    try:
        return collect_capture(content, parsed, config, request.app.state.detector, settings, session)
    except QualityRejected as exc:
        raise HTTPException(422, {"stage": exc.stage, "quality": exc.quality.model_dump()}) from exc
    except FramingError as exc:
        raise HTTPException(422, {"stage": "framing", "reason": str(exc)}) from exc
    except DetectionUnavailable as exc:
        raise HTTPException(503, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    except (OSError, SQLAlchemyError) as exc:
        logger.exception("Capture persistence failed")
        raise HTTPException(503, "Capture could not be saved; please retry") from exc
