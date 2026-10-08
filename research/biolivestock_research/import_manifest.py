"""Import explicit, human-reviewed labels; never infer identity or sessions."""

import csv
import hashlib
import json
from pathlib import Path

from app.core.species import Species
from biolivestock_research.dataset import Sample, resolve_image, validate_samples

REQUIRED = {"sample_id", "species", "animal_id", "session_id", "image_path", "reviewed_muzzle", "split", "role"}


def reviewed_csv(path: Path, root: Path, species: Species) -> list[Sample]:
    samples = []
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        headers = reader.fieldnames or []
        if len(headers) != len(set(headers)) or not REQUIRED <= set(headers):
            raise ValueError("CSV needs unique headers and all required annotation fields")
        if set(headers) - set(Sample.model_fields):
            raise ValueError("CSV contains unsupported fields; use muzzle_annotations.csv")
        for line, row in enumerate(reader, 2):
            try:
                if None in row or any(value is None for value in row.values()):
                    raise ValueError("Row length differs from headers")
                values = {key: value.strip() for key, value in row.items()}
                if values["reviewed_muzzle"].lower() != "true":
                    raise ValueError("Explicit reviewed_muzzle=true is required")
                values["reviewed_muzzle"] = True
                relative = values["image_path"]
                if "\\" in relative or ":" in relative:
                    raise ValueError("Use portable relative paths with forward slashes")
                actual_hash = hashlib.sha256(resolve_image(root, relative).read_bytes()).hexdigest()
                if values.get("sha256") and values["sha256"] != actual_hash:
                    raise ValueError("Supplied checksum differs from crop bytes")
                values["sha256"] = actual_hash
                for key in ("farm_id", "camera_id"):
                    if not values.get(key):
                        values[key] = None
                samples.append(Sample.model_validate(values))
            except (ValueError, OSError) as exc:
                raise ValueError(f"CSV line {line}: {exc}") from exc
    validate_samples(samples, root, species)
    return samples


def write_manifest(path: Path, samples: list[Sample]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump([sample.model_dump(mode="json") for sample in samples], stream, indent=2, allow_nan=False)
        stream.write("\n")
