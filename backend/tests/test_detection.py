import hashlib
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


def synthetic_model():
    # Mock tensors/inference only; no real checkpoint or animal accuracy is implied.
    tensor = SimpleNamespace(cpu=lambda: SimpleNamespace(tolist=lambda: [200, 140, 400, 340]))

    class Boxes:
        def __init__(self):
            self.xyxy = [tensor]
            self.conf = [SimpleNamespace(cpu=lambda: 0.9)]

        def __len__(self):
            return 1

    return SimpleNamespace(names={0: "muzzle"}, predict=lambda *args, **kwargs: [SimpleNamespace(boxes=Boxes())])


def test_checkpoint_changed_during_load_is_not_cached(tmp_path, sharp, config, monkeypatch):
    path = tmp_path / config.model.checkpoint
    path.parent.mkdir(parents=True)
    path.write_bytes(b"old synthetic weights")

    def changing_loader(*args, **kwargs):
        model = synthetic_model()
        path.write_bytes(b"replacement synthetic weights")
        return model

    monkeypatch.setitem(sys.modules, "ultralytics", SimpleNamespace(YOLO=changing_loader))
    detector = NoseDetector(tmp_path)
    with pytest.raises(DetectionUnavailable, match="changed while loading"):
        detector.detect(sharp, config)
    assert detector._models == {}
    monkeypatch.setitem(sys.modules, "ultralytics", SimpleNamespace(YOLO=lambda *args, **kwargs: synthetic_model()))
    result = detector.detect(sharp, config)
    assert result.metadata["checkpoint_sha256"] == hashlib.sha256(path.read_bytes()).hexdigest()


def test_checkpoint_replacements_evict_old_weights_and_record_loaded_digest(tmp_path, sharp, config, monkeypatch):
    path = tmp_path / config.model.checkpoint
    path.parent.mkdir(parents=True)
    calls = []

    def loader(*args, **kwargs):
        calls.append(path.read_bytes())
        return synthetic_model()

    monkeypatch.setitem(sys.modules, "ultralytics", SimpleNamespace(YOLO=loader))
    detector = NoseDetector(tmp_path)
    for content in [b"synthetic 1", b"synthetic weights 2", b"synthetic weights version 3"]:
        path.write_bytes(content)
        for _ in range(2):
            result = detector.detect(sharp, config)
            assert result.metadata["checkpoint_sha256"] == hashlib.sha256(content).hexdigest()
        assert len(detector._models) == 1
    assert len(calls) == 3
