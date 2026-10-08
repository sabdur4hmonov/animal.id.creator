import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

import numpy as np

from biolivestock_research.dataset import Sample, load_manifest, manifest_digest, resolve_image
from biolivestock_research.embedding import FeatureExtractor, load_config, normalize_vectors
from biolivestock_research.import_manifest import reviewed_csv, write_manifest
from biolivestock_research.matching import evaluate


def write_report(path: Path, report: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2, allow_nan=False)
        stream.write("\n")


def extract(args):
    config = load_config(args.config)
    samples = load_manifest(args.manifest, args.dataset_root, config.species)
    extractor = FeatureExtractor(config, args.model_root)
    vectors = extractor.encode([resolve_image(args.dataset_root, sample.image_path) for sample in samples])
    metadata = {
        "created_at": datetime.now(UTC).isoformat(),
        "research_only": True,
        "config": config.model_dump(mode="json"),
        "manifest_sha256": manifest_digest(samples),
        "samples": [sample.model_dump(mode="json") for sample in samples],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("xb") as stream:
        np.savez_compressed(stream, embeddings=vectors, metadata=json.dumps(metadata, allow_nan=False))
    print(f"Saved {len(samples)} research embeddings to {args.output}")


def evaluate_archive(args):
    with np.load(args.artifact, allow_pickle=False) as archive:
        vectors = normalize_vectors(archive["embeddings"])
        metadata = json.loads(str(archive["metadata"]))
    config = load_config(args.config)
    if metadata["config"] != config.model_dump(mode="json") or metadata.get("research_only") is not True:
        raise ValueError("Artifact configuration/provenance mismatch")
    if vectors.shape[1] != config.dimensions:
        raise ValueError("Artifact feature dimensions mismatch")
    samples = [Sample.model_validate(value) for value in metadata["samples"]]
    if any(sample.species != config.species for sample in samples):
        raise ValueError("Artifact species differs from selected configuration")
    if manifest_digest(samples) != metadata["manifest_sha256"]:
        raise ValueError("Artifact manifest fingerprint mismatch")
    report = evaluate(samples, vectors, args.split, args.threshold)
    report["provenance"] = {"config": metadata["config"], "manifest_sha256": metadata["manifest_sha256"]}
    write_report(args.output, report)
    print(f"Saved research evaluation to {args.output}")


def smoke(args):
    config = load_config(args.config)
    vectors = FeatureExtractor(config, args.model_root).encode([args.image, args.image])
    score = float(vectors[0] @ vectors[1])
    if not np.allclose(np.linalg.norm(vectors, axis=1), 1, atol=1e-5) or score < 0.999:
        raise ValueError("Repeat feature extraction was not stable/unit-normalized")
    write_report(
        args.output,
        {
            "research_only": True,
            "kind": "feature_extraction_smoke_not_biometric_accuracy",
            "image": str(args.image),
            "dimensions": config.dimensions,
            "repeat_cosine": score,
            "config": config.model_dump(mode="json"),
        },
    )
    print(f"Verified {config.dimensions}-dimensional CPU features; repeat cosine={score:.6f}")


def main():
    parser = argparse.ArgumentParser(description="Offline cattle embeddings/matching evaluation only")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("import-csv", "validate", "extract", "evaluate", "smoke"):
        command = sub.add_parser(name)
        command.add_argument("--config", type=Path, required=True)
        if name == "import-csv":
            command.add_argument("--csv", type=Path, required=True)
            command.add_argument("--dataset-root", type=Path, required=True)
        if name in ("validate", "extract"):
            command.add_argument("--manifest", type=Path, required=True)
            command.add_argument("--dataset-root", type=Path, required=True)
        if name in ("extract", "smoke"):
            command.add_argument("--model-root", type=Path, required=True)
        if name != "validate":
            command.add_argument("--output", type=Path, required=True)
        if name == "smoke":
            command.add_argument("--image", type=Path, required=True)
        if name == "evaluate":
            command.add_argument("--artifact", type=Path, required=True)
            command.add_argument("--split", choices=["validation", "test"], required=True)
            command.add_argument("--threshold", type=float, required=True)
    args = parser.parse_args()
    if args.command == "import-csv":
        config = load_config(args.config)
        samples = reviewed_csv(args.csv, args.dataset_root, config.species)
        write_manifest(args.output, samples)
        print(f"Imported {len(samples)} reviewed crops; manifest SHA-256={manifest_digest(samples)}")
    elif args.command == "validate":
        config = load_config(args.config)
        samples = load_manifest(args.manifest, args.dataset_root, config.species)
        print(f"Validated {len(samples)} reviewed samples; manifest SHA-256={manifest_digest(samples)}")
    elif args.command == "extract":
        extract(args)
    elif args.command == "evaluate":
        evaluate_archive(args)
    else:
        smoke(args)
