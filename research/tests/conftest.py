import hashlib

import pytest
from PIL import Image

from app.core.species import Species
from biolivestock_research.dataset import Sample


@pytest.fixture
def samples(tmp_path):
    values = []
    for index, (animal, role, session) in enumerate(
        [
            ("A", "gallery", "day-1"),
            ("B", "gallery", "day-1"),
            ("A", "query", "day-2"),
            ("UNKNOWN", "query", "day-2"),
        ]
    ):
        path = tmp_path / f"{index}.png"
        Image.new("RGB", (64, 48), (index * 40, 100, 150)).save(path)
        values.append(
            Sample(
                sample_id=str(index),
                species=Species.cattle,
                animal_id=animal,
                session_id=session,
                split="test",
                role=role,
                image_path=path.name,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                reviewed_muzzle=True,
            )
        )
    return values
