import hashlib
import json
from pathlib import Path
from typing import Literal

from PIL import Image, ImageOps
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.species import Species


class Sample(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sample_id: str = Field(min_length=1)
    species: Species
    animal_id: str = Field(min_length=1)
    session_id: str = Field(min_length=1)
    farm_id: str | None = None
    camera_id: str | None = None
    split: Literal["train", "validation", "test"]
    role: Literal["train", "gallery", "query"]
    image_path: str
    sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    reviewed_muzzle: Literal[True]

    @field_validator("sample_id", "animal_id", "session_id")
    @classmethod
    def nonblank_label(cls, value):
        if not value.strip():
            raise ValueError("Identity/session labels cannot be blank")
        return value.strip()

    @model_validator(mode="after")
    def compatible_role(self):
        if (self.split == "train") != (self.role == "train"):
            raise ValueError("Train samples use role=train; evaluation samples use gallery/query")
        return self


def resolve_image(root: Path, relative: str) -> Path:
    if Path(relative).is_absolute():
        raise ValueError("Image paths must be relative to the dataset root")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("Image path escapes dataset root")
    return path


def validate_samples(samples: list[Sample], root: Path, species: Species) -> None:
    validate_protocol(samples, species)
    for sample in samples:
        path = resolve_image(root, sample.image_path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != sample.sha256:
            raise ValueError(f"Image checksum mismatch: {sample.sample_id}")
        with Image.open(path) as image:
            if image.format not in ("JPEG", "PNG") or image.width * image.height > 25_000_000:
                raise ValueError("Expected a JPEG/PNG muzzle image within 25 million pixels")
            image.verify()
        try:
            # verify() checks structure; extraction also needs fully decodable pixels.
            with Image.open(path) as image:
                ImageOps.exif_transpose(image).convert("RGB").load()
        except (OSError, ValueError) as exc:
            raise ValueError(f"Undecodable image pixels: {sample.sample_id} ({sample.image_path})") from exc


def validate_protocol(samples: list[Sample], species: Species) -> None:
    if not samples:
        raise ValueError("Dataset is empty")
    ids, hashes, animal_splits = set(), set(), {}
    for sample in samples:
        if sample.species != species:
            raise ValueError("Mixed or unexpected species in manifest")
        if sample.sample_id in ids or sample.sha256 in hashes:
            raise ValueError("Duplicate sample ID or image content")
        ids.add(sample.sample_id)
        hashes.add(sample.sha256)
        previous = animal_splits.setdefault(sample.animal_id, sample.split)
        if previous != sample.split:
            raise ValueError("Animal identity leaks across train/validation/test splits")
    validate_sessions(samples)


def validate_sessions(samples: list[Sample]) -> None:
    for split in ("validation", "test"):
        entries = [sample for sample in samples if sample.split == split]
        if not entries:
            continue
        gallery = [sample for sample in entries if sample.role == "gallery"]
        queries = [sample for sample in entries if sample.role == "query"]
        if not gallery or not queries:
            raise ValueError(f"{split} needs gallery and query samples")
        for query in queries:
            if any(
                item.animal_id == query.animal_id and item.session_id == query.session_id for item in gallery
            ):
                raise ValueError("Same-animal gallery/query captures must come from different sessions")


def load_manifest(path: Path, root: Path, species: Species) -> list[Sample]:
    samples = [Sample.model_validate(value) for value in json.loads(path.read_text(encoding="utf-8"))]
    validate_samples(samples, root, species)
    return samples


def manifest_digest(samples: list[Sample]) -> str:
    payload = json.dumps([item.model_dump(mode="json") for item in samples], sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()
