import json

import pytest
from pydantic import ValidationError

from app.core.species import Species
from biolivestock_research.dataset import Sample, load_manifest, validate_samples


def test_reviewed_multisession_manifest_loads(samples, tmp_path):
    path = tmp_path / "manifest.json"
    path.write_text(json.dumps([sample.model_dump(mode="json") for sample in samples]), encoding="utf-8")
    assert load_manifest(path, tmp_path, Species.cattle) == samples


@pytest.mark.parametrize(
    ("index", "updates", "message"),
    [
        (2, {"split": "validation"}, "leaks across"),
        (2, {"session_id": "day-1"}, "different sessions"),
        (2, {"image_path": "../outside.png"}, "escapes"),
        (2, {"sha256": "0" * 64}, "checksum mismatch"),
        (2, {"species": Species.sheep}, "species"),
        (2, {"sample_id": "0"}, "Duplicate"),
    ],
)
def test_manifest_rejects_leakage_or_corruption(samples, tmp_path, index, updates, message):
    samples[index] = samples[index].model_copy(update=updates)
    with pytest.raises(ValueError, match=message):
        validate_samples(samples, tmp_path, Species.cattle)


def test_duplicate_content_is_rejected_even_with_different_sample_id(samples, tmp_path):
    samples[2] = samples[2].model_copy(
        update={"sha256": samples[0].sha256, "image_path": samples[0].image_path}
    )
    with pytest.raises(ValueError, match="Duplicate"):
        validate_samples(samples, tmp_path, Species.cattle)


def test_unreviewed_pending_capture_cannot_enter_dataset(samples):
    value = samples[0].model_dump()
    value["reviewed_muzzle"] = False
    with pytest.raises(ValidationError):
        Sample.model_validate(value)


@pytest.mark.parametrize("field", ["sample_id", "animal_id", "session_id"])
def test_blank_ground_truth_label_is_rejected(samples, field):
    value = samples[0].model_dump()
    value[field] = "  "
    with pytest.raises(ValidationError):
        Sample.model_validate(value)


def test_no_query_partition_is_rejected(samples, tmp_path):
    with pytest.raises(ValueError, match="gallery and query"):
        validate_samples(samples[:2], tmp_path, Species.cattle)
