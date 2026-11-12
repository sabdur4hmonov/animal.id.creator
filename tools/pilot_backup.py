"""Scheduled consistent backup and restore-to-new-clone verification. No automatic purge."""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]


def run_backup(args):
    roots = [
        args.storage_root.resolve(),
        args.backup_root.resolve(),
        args.restore_root.resolve(),
    ]
    if any(
        a == b or a.is_relative_to(b) or b.is_relative_to(a)
        for i, a in enumerate(roots)
        for b in roots[i + 1 :]
    ):
        raise ValueError(
            "Storage, backup and clone roots must be separate, non-nested directories"
        )
    if not roots[0].is_dir():
        raise ValueError("Storage root is missing")
    for directory in roots[1:]:
        directory.mkdir(parents=True, exist_ok=True)
    free = shutil.disk_usage(roots[1]).free
    source_bytes = sum(
        f.stat().st_size
        for species in ("cattle", "sheep", "research")
        for f in (roots[0] / species).rglob("*")
        if f.is_file()
    )
    if free < max(args.min_free_gib * 1024**3, source_bytes * 3):
        raise ValueError(
            "Insufficient free backup space; no backup or container stop attempted"
        )
    lock = roots[1] / ".backup-running"
    with lock.open("x", encoding="utf-8") as stream:
        stream.write(str(os.getpid()))
    try:
        name = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:8]
        bundle = roots[1] / name
        clone = roots[2] / name
        database = "biolivestock_restore_" + uuid4().hex[:20]
        common = [
            sys.executable,
            str(ROOT / "tools/collection_storage.py"),
            "--compose-file",
            str(args.compose_file.resolve()),
        ]
        if args.env_file:
            common += ["--env-file", str(args.env_file.resolve())]
        subprocess.run(
            [
                *common,
                "backup",
                "--project",
                args.project,
                "--storage-root",
                str(roots[0]),
                "--output",
                str(bundle),
            ],
            check=True,
        )
        subprocess.run([*common, "verify", "--bundle", str(bundle)], check=True)
        subprocess.run(
            [
                *common,
                "restore",
                "--project",
                args.project,
                "--bundle",
                str(bundle),
                "--target-database",
                database,
                "--target-storage",
                str(clone),
            ],
            check=True,
        )
        evidence = {
            "version": 1,
            "verified_at": datetime.now(UTC).isoformat(),
            "project": args.project,
            "bundle": str(bundle),
            "clone_database": database,
            "clone_storage": str(clone),
            "restore_verified": True,
            "live_promoted": False,
            "automatic_deletion": False,
        }
        with (roots[1] / (name + "-verified.json")).open(
            "x", encoding="utf-8"
        ) as stream:
            json.dump(evidence, stream, indent=2)
        return evidence
    finally:
        lock.unlink()  # Only this process's newly created coordination file.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--compose-file", type=Path, required=True)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--storage-root", type=Path, required=True)
    parser.add_argument("--backup-root", type=Path, required=True)
    parser.add_argument("--restore-root", type=Path, required=True)
    parser.add_argument("--min-free-gib", type=int, default=10)
    args = parser.parse_args()
    if args.min_free_gib < 1:
        parser.error("Reserve at least 1 GiB")
    os.umask(0o077)
    evidence = run_backup(args)
    print("Backup and isolated clone restore verified: " + evidence["bundle"])


if __name__ == "__main__":
    main()
