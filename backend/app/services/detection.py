"""Species-configured YOLOv8n inference; no implicit weights download or fake crop."""

import hashlib
from dataclasses import dataclass
from pathlib import Path
from threading import Lock

import numpy as np

from app.core.species import CropConfig, SpeciesConfig


class DetectionUnavailable(Exception):
    pass


class FramingError(Exception):
    pass


@dataclass
class DetectionResult:
    crop: np.ndarray
    metadata: dict


def crop_box(image: np.ndarray, box: list[float], config: CropConfig) -> tuple[np.ndarray, list[int]]:
    height, width = image.shape[:2]
    x1, y1, x2, y2 = box
    if not all(np.isfinite(box)) or x2 <= x1 or y2 <= y1:
        raise FramingError("invalid_box")
    bw, bh = x2 - x1, y2 - y1
    if bw < config.min_width or bh < config.min_height or bw * bh / (width * height) < config.min_area_ratio:
        raise FramingError("muzzle_too_small")
    margin = config.edge_margin_ratio
    if x1 < width * margin or y1 < height * margin or x2 > width * (1 - margin) or y2 > height * (1 - margin):
        raise FramingError("muzzle_cut_off")
    pad = config.padding_ratio
    bounds = [
        max(0, int(x1 - bw * pad)),
        max(0, int(y1 - bh * pad)),
        min(width, int(np.ceil(x2 + bw * pad))),
        min(height, int(np.ceil(y2 + bh * pad))),
    ]
    left, top, right, bottom = bounds
    return image[top:bottom, left:right].copy(), bounds


class NoseDetector:
    def __init__(self, model_root: Path):
        self.model_root = model_root.resolve()
        self._models: dict = {}
        self._lock = Lock()

    def checkpoint(self, config: SpeciesConfig) -> Path:
        path = (self.model_root / config.model.checkpoint).resolve()
        if not path.is_relative_to(self.model_root):
            raise ValueError("Model checkpoint must be within model_root")
        return path

    def detect(self, image: np.ndarray, config: SpeciesConfig) -> DetectionResult | None:
        path = self.checkpoint(config)
        if not path.is_file():
            return None
        # Ultralytics predictor instances are stateful; serialize model access.
        with self._lock:
            try:
                key = (str(path), path.stat().st_mtime_ns, path.stat().st_size)
                if key not in self._models:
                    from ultralytics import YOLO

                    model = YOLO(str(path), task="detect")
                    digest = hashlib.sha256(path.read_bytes()).hexdigest()
                    self._models[key] = (model, digest)
                model, digest = self._models[key]
                matches = [i for i, name in model.names.items() if name == config.model.class_name]
                if len(matches) != 1:
                    raise DetectionUnavailable("Checkpoint must contain the configured muzzle class")
                result = model.predict(
                    image,
                    conf=config.model.confidence,
                    classes=matches,
                    imgsz=config.model.image_size,
                    device="cpu",
                    verbose=False,
                )[0]
            except DetectionUnavailable:
                raise
            except Exception as exc:
                raise DetectionUnavailable("Checkpoint could not be loaded or used") from exc
            boxes = result.boxes
            if boxes is None or len(boxes) == 0:
                raise FramingError("no_muzzle_detected")
            if len(boxes) != 1:
                raise FramingError("multiple_muzzles_detected")
            box = boxes.xyxy[0].cpu().tolist()
            confidence = float(boxes.conf[0].cpu())
            crop, bounds = crop_box(image, box, config.crop)
            return DetectionResult(
                crop=crop,
                metadata={
                    "species": config.species.value,
                    "box_xyxy": box,
                    "crop_xyxy": bounds,
                    "confidence": confidence,
                    "class_name": config.model.class_name,
                    "checkpoint": config.model.checkpoint,
                    "checkpoint_sha256": digest,
                },
            )
