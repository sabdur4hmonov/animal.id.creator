import warnings
from datetime import UTC
from io import BytesIO
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

from app.schemas.capture import CaptureMetadata


def decode_image(content: bytes, max_pixels: int) -> np.ndarray:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(content)) as source:
                if source.format not in ("JPEG", "PNG"):
                    raise ValueError("Only JPEG and PNG images are accepted")
                if source.width * source.height > max_pixels:
                    raise ValueError("Image exceeds pixel limit")
                rgb = np.asarray(ImageOps.exif_transpose(source).convert("RGB"))
                return cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    except (
        UnidentifiedImageError,
        OSError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ) as exc:
        raise ValueError("Invalid or oversized image") from exc


def write_image(root: Path, metadata: CaptureMetadata, capture_id: str, kind: str, image: np.ndarray) -> str:
    date = metadata.timestamp.astimezone(UTC).date().isoformat()
    relative = Path(metadata.species.value) / metadata.animal_id / date / f"{capture_id}_{kind}.jpg"
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    ok, encoded = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 95])
    if not ok:
        raise OSError("JPEG encoding failed")
    created = False
    try:
        with target.open("xb") as stream:
            created = True
            stream.write(encoded.tobytes())
    except Exception:
        if created:
            target.unlink(missing_ok=True)
        raise
    return relative.as_posix()
