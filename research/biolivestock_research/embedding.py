import hashlib
from pathlib import Path

import numpy as np
import yaml
from PIL import Image, ImageOps
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.species import Species


class EmbeddingConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    species: Species
    enabled: bool
    config_version: int = Field(ge=1)
    architecture: str
    feature_node: str
    dimensions: int = Field(gt=0)
    checkpoint: str
    checkpoint_sha256: str | None = Field(default=None, pattern=r"^[a-f0-9]{64}$")
    input_size: int = Field(ge=32, le=1024)
    mean: tuple[float, float, float]
    std: tuple[float, float, float]
    padding_rgb: tuple[int, int, int]

    @model_validator(mode="after")
    def valid_normalization(self):
        if any(not 0 <= value <= 1 for value in self.mean) or any(value <= 0 for value in self.std):
            raise ValueError("Invalid normalization mean/std")
        if any(not 0 <= value <= 255 for value in self.padding_rgb):
            raise ValueError("Invalid RGB padding color")
        return self


def load_config(path: Path) -> EmbeddingConfig:
    config = EmbeddingConfig.model_validate(yaml.safe_load(path.read_text(encoding="utf-8")))
    if not config.enabled:
        raise ValueError("Species research is disabled")
    return config


def normalize_vectors(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=np.float32)
    if values.ndim != 2 or not values.size or not np.isfinite(values).all():
        raise ValueError("Expected a nonempty finite embedding matrix")
    norms = np.linalg.norm(values, axis=1, keepdims=True)
    if not np.isfinite(norms).all() or np.any(norms <= 0):
        raise ValueError("Embeddings must have finite nonzero norms")
    return values / norms


def preprocess(image: Image.Image, config: EmbeddingConfig) -> np.ndarray:
    # Preserve all reviewed muzzle content instead of cropping/stretching it again.
    image = ImageOps.exif_transpose(image).convert("RGB")
    image = ImageOps.pad(
        image,
        (config.input_size, config.input_size),
        method=Image.Resampling.BILINEAR,
        color=config.padding_rgb,
    )
    pixels = np.asarray(image, dtype=np.float32) / 255
    pixels = (pixels - np.array(config.mean, np.float32)) / np.array(config.std, np.float32)
    return np.transpose(pixels, (2, 0, 1)).copy()


class FeatureExtractor:
    def __init__(self, config: EmbeddingConfig, model_root: Path):
        if not config.enabled:
            raise ValueError("Species research is disabled")
        path = (model_root / config.checkpoint).resolve()
        if not path.is_relative_to(model_root.resolve()):
            raise ValueError("Checkpoint escapes model root")
        if not config.checkpoint_sha256:
            raise ValueError("Set a verified checkpoint SHA-256 before extraction")
        if hashlib.sha256(path.read_bytes()).hexdigest() != config.checkpoint_sha256:
            raise ValueError("Checkpoint checksum mismatch")
        # Imports are optional for dataset/metric tools; never download weights implicitly.
        import torch
        from torchvision.models import get_model
        from torchvision.models.feature_extraction import create_feature_extractor

        model = get_model(config.architecture, weights=None)
        model.load_state_dict(torch.load(path, map_location="cpu", weights_only=True))
        self.model = create_feature_extractor(model, return_nodes={config.feature_node: "embedding"}).eval()
        self.config = config
        self.torch = torch

    def encode(self, paths: list[Path]) -> np.ndarray:
        vectors = []
        with self.torch.inference_mode():
            for path in paths:
                with Image.open(path) as image:
                    pixels = preprocess(image, self.config)
                tensor = self.torch.from_numpy(pixels).unsqueeze(0)
                vector = self.model(tensor)["embedding"].flatten(1).cpu().numpy()
                if vector.shape != (1, self.config.dimensions):
                    raise ValueError("Model feature dimensions differ from configuration")
                vectors.append(vector[0])
        return normalize_vectors(np.asarray(vectors))
