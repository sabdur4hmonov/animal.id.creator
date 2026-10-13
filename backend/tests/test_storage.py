import os
import subprocess
from io import BytesIO
from uuid import uuid4

import numpy as np
import pytest
from PIL import Image

from app.schemas.capture import CaptureMetadata
from app.services.storage import decode_image, write_image


def test_png_is_decoded_to_expected_bgr_pixels():
    buffer = BytesIO()
    Image.new("RGB", (20, 40), (255, 0, 0)).save(buffer, format="PNG")
    decoded = decode_image(buffer.getvalue(), 1000)
    assert decoded.shape == (40, 20, 3)
    np.testing.assert_array_equal(decoded[0, 0], [0, 0, 255])


def test_jpeg_sensor_orientation_is_applied():
    buffer = BytesIO()
    exif = Image.Exif()
    exif[274] = 6  # Camera orientation: rotate 90 degrees clockwise.
    Image.new("RGB", (40, 20), (200, 100, 50)).save(buffer, format="JPEG", exif=exif)
    assert decode_image(buffer.getvalue(), 1000).shape == (40, 20, 3)


def test_gif_is_rejected_even_if_it_contains_valid_pixels():
    buffer = BytesIO()
    Image.new("RGB", (20, 20), (100, 100, 100)).save(buffer, format="GIF")
    with pytest.raises(ValueError, match="Only JPEG and PNG"):
        decode_image(buffer.getvalue(), 1000)


def test_truncated_jpeg_is_rejected(jpeg):
    with pytest.raises(ValueError, match="Invalid or oversized"):
        decode_image(jpeg[:-100], 1_000_000)


@pytest.mark.parametrize("outside", [True, False])
def test_capture_write_rejects_directory_redirect_before_creating_files(tmp_path, metadata, sharp, outside):
    root = tmp_path / "store"
    root.mkdir()
    destination = tmp_path / "outside" if outside else root / "other-animals"
    destination.mkdir()
    link = root / "cattle"
    if os.name == "nt":
        result = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(destination)],
                                capture_output=True, text=True, check=True)
        assert result.returncode == 0
        assert link.is_junction()
    else:
        link.symlink_to(destination, target_is_directory=True)
    with pytest.raises(OSError, match="escapes|Linked"):
        write_image(root, CaptureMetadata.model_validate(metadata), str(uuid4()), "original", sharp)
    assert list(destination.iterdir()) == []
