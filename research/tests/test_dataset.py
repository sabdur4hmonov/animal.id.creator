import hashlib
import json
from io import BytesIO

import pytest
from PIL import Image
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


def test_truncated_jpeg_pixels_cannot_enter_manifest(tmp_path):
    buffer = BytesIO()
    Image.new("RGB", (128, 128), (100, 150, 200)).save(buffer, format="JPEG")
    path = tmp_path / "truncated.jpg"
    path.write_bytes(buffer.getvalue()[:-100])
    sample = Sample(sample_id="bad", species=Species.cattle, animal_id="A", session_id="S",
                    split="train", role="train", image_path=path.name,
                    sha256=hashlib.sha256(path.read_bytes()).hexdigest(), reviewed_muzzle=True)
    with pytest.raises(ValueError, match="Undecodable.*bad"):
        validate_samples([sample], tmp_path, Species.cattle)


@pytest.mark.parametrize("oriented", [False, True])
def test_identical_pixels_reencoded_or_exif_rotated_are_rejected(tmp_path, oriented):
    image = Image.new("RGB", (48, 64), (30, 100, 150))
    image.putpixel((2, 7), (200, 50, 40))
    first, second = tmp_path / "a.png", tmp_path / "b.png"
    if oriented:
        exif = Image.Exif()
        exif[274] = 6
        image.save(first, exif=exif)
        image.transpose(Image.Transpose.ROTATE_270).save(second)
    else:
        image.save(first, compress_level=0)
        image.save(second, compress_level=9)
    assert first.read_bytes() != second.read_bytes()
    samples = [Sample(sample_id=path.stem, species=Species.cattle, animal_id=path.stem,
                      session_id="S", split="train", role="train", image_path=path.name,
                      sha256=hashlib.sha256(path.read_bytes()).hexdigest(), reviewed_muzzle=True)
               for path in (first, second)]
    with pytest.raises(ValueError, match="Duplicate decoded pixels: a and b"):
        validate_samples(samples, tmp_path, Species.cattle)
