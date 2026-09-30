import sys
from types import SimpleNamespace

import numpy as np
import pytest

from app.services.detection import DetectionUnavailable, FramingError, NoseDetector, crop_box


def test_missing_model_is_pending(tmp_path, sharp, config):
    assert NoseDetector(tmp_path).detect(sharp, config) is None


def test_crop_padding(sharp, config):
    crop, bounds = crop_box(sharp, [200, 140, 400, 340], config.crop)
    assert bounds == [180, 120, 420, 360]
    np.testing.assert_array_equal(crop, sharp[120:360, 180:420])


@pytest.mark.parametrize("box", [[0, 0, 200, 200], [200, 200, 210, 210], [500, 100, 400, 300]])
def test_bad_framing(sharp, config, box):
    with pytest.raises(FramingError):
        crop_box(sharp, box, config.crop)


def test_model_must_have_muzzle_class(tmp_path, sharp, config, monkeypatch):
    path = tmp_path / config.model.checkpoint
    path.parent.mkdir(parents=True)
    path.write_bytes(b"test checkpoint placeholder")
    monkeypatch.setitem(
        sys.modules, "ultralytics", SimpleNamespace(YOLO=lambda *a, **k: SimpleNamespace(names={0: "cow"}))
    )
    with pytest.raises(DetectionUnavailable, match="configured muzzle class"):
        NoseDetector(tmp_path).detect(sharp, config)
