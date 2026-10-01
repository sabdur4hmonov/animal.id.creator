from io import BytesIO

import numpy as np
import pytest
from PIL import Image

from app.services.storage import decode_image


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
