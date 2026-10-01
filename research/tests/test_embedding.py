from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from biolivestock_research.embedding import FeatureExtractor, load_config, normalize_vectors, preprocess

CONFIG_DIR = Path(__file__).resolve().parents[1] / "species_configs"


def test_sheep_research_stays_disabled():
    with pytest.raises(ValueError, match="disabled"):
        load_config(CONFIG_DIR / "sheep.yaml")


def test_checkpoint_is_verified_before_torch_loading(tmp_path):
    config = load_config(CONFIG_DIR / "cattle.yaml")
    checkpoint = tmp_path / config.checkpoint
    checkpoint.parent.mkdir(parents=True)
    checkpoint.write_bytes(b"not trusted weights")
    with pytest.raises(ValueError, match="checksum mismatch"):
        FeatureExtractor(config, tmp_path)


def test_preprocessing_preserves_entire_muzzle_and_pads_aspect_ratio():
    config = load_config(CONFIG_DIR / "cattle.yaml")
    image = Image.new("RGB", (40, 20), (255, 0, 0))
    tensor = preprocess(image, config)
    assert tensor.shape == (3, 224, 224)
    restored = np.transpose(tensor, (1, 2, 0)) * config.std + config.mean
    assert restored[0, 0] == pytest.approx(np.array(config.padding_rgb) / 255)
    assert restored[112, 112] == pytest.approx([1, 0, 0], abs=1e-6)


def test_embeddings_are_unit_normalized():
    np.testing.assert_allclose(normalize_vectors(np.array([[3, 4], [0, 2]])), [[0.6, 0.8], [0, 1]])
