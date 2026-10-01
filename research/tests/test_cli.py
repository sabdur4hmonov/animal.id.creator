import json
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pytest
import yaml

from biolivestock_research.cli import evaluate_archive, write_report
from biolivestock_research.dataset import manifest_digest
from biolivestock_research.embedding import load_config


@pytest.fixture
def artifact_args(tmp_path, samples):
    config = load_config(Path(__file__).resolve().parents[1] / "species_configs" / "cattle.yaml")
    config = config.model_copy(update={"dimensions": 2})
    path = tmp_path / "config.yaml"
    path.write_text(yaml.safe_dump(config.model_dump(mode="json")), encoding="utf-8")
    metadata = {
        "research_only": True,
        "config": config.model_dump(mode="json"),
        "samples": [sample.model_dump(mode="json") for sample in samples],
        "manifest_sha256": manifest_digest(samples),
    }
    artifact = tmp_path / "embeddings.npz"
    np.savez(artifact, embeddings=np.array([[1, 0], [0, 1], [1, 0], [-1, 0]]), metadata=json.dumps(metadata))
    return SimpleNamespace(
        config=path, artifact=artifact, split="test", threshold=0.5, output=tmp_path / "report.json"
    )


def test_archive_evaluation_writes_provenance_and_metrics(artifact_args):
    evaluate_archive(artifact_args)
    result = json.loads(artifact_args.output.read_text(encoding="utf-8"))
    assert result["known_query_failure_rate"] == 0
    assert result["provenance"]["config"]["dimensions"] == 2
    assert result["research_only"]


def test_configuration_change_invalidates_embedding_archive(artifact_args):
    values = yaml.safe_load(artifact_args.config.read_text(encoding="utf-8"))
    values["input_size"] = 256
    artifact_args.config.write_text(yaml.safe_dump(values), encoding="utf-8")
    with pytest.raises(ValueError, match="configuration/provenance"):
        evaluate_archive(artifact_args)
    assert not artifact_args.output.exists()


def test_reports_cannot_overwrite_previous_evidence(tmp_path):
    path = tmp_path / "report.json"
    write_report(path, {"original": True})
    with pytest.raises(FileExistsError):
        write_report(path, {"replaced": True})
    assert json.loads(path.read_text()) == {"original": True}
