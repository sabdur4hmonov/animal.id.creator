"""Synthetic restore copy corruption probe; Docker is mocked and never invoked."""

import json
import sys
import tempfile
from argparse import Namespace
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / "work/audit_20261013"
WORK.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT))
from tools import collection_storage as storage

root = Path(tempfile.mkdtemp(prefix="recovery-", dir=WORK))
bundle = root / "bundle"
(bundle / "files/cattle/A").mkdir(parents=True)
(bundle / "files/research").mkdir()
(bundle / "files/cattle/A/original.jpg").write_bytes(b"original-evidence")
(bundle / "files/cattle/A/muzzle.jpg").write_bytes(b"crop-evidence")
(bundle / "files/research/scans.csv").write_text("ground-truth labels", "utf-8")
records = [
    {
        "id": "capture",
        "file_path": "cattle/A/original.jpg",
        "crop_path": "cattle/A/muzzle.jpg",
        "stored_sha256": storage.digest(bundle / "files/cattle/A/original.jpg"),
    }
]
(bundle / "capture_index.json").write_text(json.dumps(records), "utf-8")
(bundle / "database.dump").write_bytes(b"PGDMP-placeholder-not-a-real-dump")
manifest = {
    "version": 1,
    "table_counts": {"captures": 1},
    "files": {
        p.relative_to(bundle).as_posix(): storage.digest(p)
        for p in bundle.rglob("*")
        if p.is_file()
    },
}
(bundle / "manifest.json").write_text(json.dumps(manifest), "utf-8")
original_copy = storage.copy_tree


def corrupt_after_copy(source, destination):
    original_copy(source, destination)
    (destination / "cattle/A/muzzle.jpg").write_bytes(b"CORRUPTED-CROP")
    (destination / "research/scans.csv").write_text("CORRUPTED-LABELS", "utf-8")


log = StringIO()
with (
    patch.object(storage, "query", return_value=""),
    patch.object(storage, "run"),
    patch.object(storage, "counts", return_value={"captures": 1}),
    patch.object(storage, "capture_index", return_value=records),
    patch.object(storage, "copy_tree", corrupt_after_copy),
    redirect_stdout(log),
):
    storage.restore(
        Namespace(
            bundle=bundle,
            project="audit",
            target_database="biolivestock_restore_audit",
            target_storage=root / "restored",
        )
    )
result = {
    "docker_used": False,
    "fault": "Corrupt crop and research labels during destination copy",
    "restore_output": log.getvalue().strip(),
    "restored_crop_matches_bundle": storage.digest(
        root / "restored/cattle/A/muzzle.jpg"
    )
    == manifest["files"]["files/cattle/A/muzzle.jpg"],
    "restored_labels_match_bundle": storage.digest(root / "restored/research/scans.csv")
    == manifest["files"]["files/research/scans.csv"],
}
(WORK / "recovery_results.json").write_text(json.dumps(result, indent=2), "utf-8")
print(json.dumps(result, indent=2))
