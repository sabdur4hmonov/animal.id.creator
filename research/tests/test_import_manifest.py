import csv
import sys
from pathlib import Path

import pytest
from PIL import Image

from app.core.species import Species
from biolivestock_research.cli import main
from biolivestock_research.dataset import load_manifest
from biolivestock_research.import_manifest import reviewed_csv, write_manifest


@pytest.fixture
def annotations(tmp_path):
    rows = []
    for index, (animal, session, role) in enumerate([("A", "DAY1", "gallery"), ("A", "DAY2", "query")]):
        Image.new("RGB", (128, 128), (50 + index * 40, 100, 100)).save(tmp_path / f"{index}.jpg")
        rows.append({
            "sample_id": str(index), "species": "cattle", "animal_id": animal, "session_id": session,
            "farm_id": "F01", "camera_id": "PHONE1", "image_path": f"{index}.jpg", "sha256": "",
            "reviewed_muzzle": "true", "split": "test", "role": role,
        })
    return tmp_path, rows


def read(root, rows):
    path = root / "labels.csv"
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    return reviewed_csv(path, root, Species.cattle)


def test_import_computes_crop_hashes_and_round_trips(annotations):
    root, rows = annotations
    samples = read(root, rows)
    output = root / "manifest.json"
    write_manifest(output, samples)
    assert load_manifest(output, root, Species.cattle) == samples
    assert samples[0].farm_id == "F01" and samples[0].camera_id == "PHONE1"
    with pytest.raises(FileExistsError):
        write_manifest(output, samples)


def test_import_cli_uses_species_config_and_writes_valid_manifest(annotations, monkeypatch):
    root, rows = annotations
    read(root, rows)
    config = Path(__file__).resolve().parents[1] / "species_configs/cattle.yaml"
    output = root / "cli-manifest.json"
    monkeypatch.setattr(sys, "argv", ["research", "import-csv", "--config", str(config),
                                     "--csv", str(root / "labels.csv"), "--dataset-root", str(root),
                                     "--output", str(output)])
    main()
    assert len(load_manifest(output, root, Species.cattle)) == 2


@pytest.mark.parametrize(("field", "value"), [
    ("reviewed_muzzle", "false"), ("reviewed_muzzle", ""), ("session_id", ""),
    ("animal_id", ""), ("species", "sheep"), ("image_path", "../outside.jpg"),
    ("image_path", "C:/secret.jpg"), ("sha256", "0" * 64),
])
def test_invalid_labels_are_rejected(annotations, field, value):
    root, rows = annotations
    rows[0][field] = value
    with pytest.raises(ValueError):
        read(root, rows)


@pytest.mark.parametrize("failure", ["session", "split", "duplicate", "content"])
def test_protocol_leakage_is_rejected(annotations, failure):
    root, rows = annotations
    if failure == "session":
        rows[1]["session_id"] = rows[0]["session_id"]
    elif failure == "split":
        rows[0].update(split="train", role="train")
    elif failure == "duplicate":
        rows[1]["sample_id"] = rows[0]["sample_id"]
    else:
        rows[1]["image_path"] = rows[0]["image_path"]
    with pytest.raises(ValueError):
        read(root, rows)
