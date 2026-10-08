"""Backup, verify, restore to a new clone, or reconcile collection evidence."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "backend/docker-compose.yml"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def contained(root, relative):
    if ":" in str(relative) or "\\" in str(relative):
        raise ValueError("Expected a portable relative path")
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Expected a portable relative path")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("Path escapes storage root")
    return path


def run(project, *args, **kwargs):
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", project):
        raise ValueError("Invalid Compose project name")
    result = subprocess.run(
        ["docker", "compose", "-p", project, "-f", str(COMPOSE), *args],
        cwd=ROOT, check=True, stderr=subprocess.PIPE, timeout=300, **kwargs,
    )
    return result


def query(project, sql, database="biolivestock"):
    result = run(project, "exec", "-T", "db", "psql", "-U", "biolivestock", "-d", database,
                 "-v", "ON_ERROR_STOP=1", "-Atc", sql, stdout=subprocess.PIPE)
    return result.stdout.decode("utf-8").strip()


def capture_index(project, database="biolivestock"):
    sql = """SELECT coalesce(json_agg(c), '[]'::json) FROM
             (SELECT id, species, animal_id, file_path, crop_path, stored_sha256
              FROM captures ORDER BY id) c"""
    return json.loads(query(project, sql, database))


def counts(project, database="biolivestock"):
    tables = query(project, "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename",
                   database).splitlines()
    if any(not re.fullmatch(r"[a-z_]+", name) for name in tables):
        raise ValueError("Unexpected database table name")
    return {name: int(query(project, f'SELECT count(*) FROM "{name}"', database)) for name in tables}


def reconcile(root, records):
    report = {"captures": len(records), "missing": [], "mismatch": [], "unsafe": [],
              "hash_unavailable": [], "orphans": []}
    referenced = set()
    for record in records:
        for field in ("file_path", "crop_path"):
            relative = record.get(field)
            if relative is None:
                continue
            try:
                path = contained(root, relative)
            except ValueError:
                report["unsafe"].append({"id": record["id"], "field": field, "path": relative})
                continue
            referenced.add(path)
            if not path.is_file():
                report["missing"].append(relative)
            elif field == "file_path" and record.get("stored_sha256"):
                if digest(path) != record["stored_sha256"]:
                    report["mismatch"].append(relative)
            else:
                report["hash_unavailable"].append(relative)
    # Research crops/references are intentionally outside live capture reconciliation.
    for species in ("cattle", "sheep"):
        directory = root / species
        if directory.exists():
            for file in directory.rglob("*"):
                if file.is_file() and file.resolve().is_relative_to(root.resolve()) and file.resolve() not in referenced:
                    report["orphans"].append(file.relative_to(root).as_posix())
    for field in ("missing", "mismatch", "hash_unavailable", "orphans"):
        report[field].sort()
    report["healthy"] = not any(report[key] for key in ("missing", "mismatch", "unsafe", "orphans"))
    return report


def verify_bundle(bundle):
    manifest = json.loads((bundle / "manifest.json").read_text("utf-8"))
    if manifest.get("version") != 1 or not isinstance(manifest.get("files"), dict):
        raise ValueError("Unsupported/incomplete backup manifest")
    for name, expected in manifest["files"].items():
        path = contained(bundle, name)
        if not re.fullmatch(r"[a-f0-9]{64}", expected) or not path.is_file() or digest(path) != expected:
            raise ValueError(f"Backup checksum mismatch/missing file: {name}")
    if "database.dump" not in manifest["files"] or "capture_index.json" not in manifest["files"]:
        raise ValueError("Backup has no database or capture index")
    actual = {file.relative_to(bundle).as_posix() for file in bundle.rglob("*") if file.is_file()}
    if actual != set(manifest["files"]) | {"manifest.json"}:
        raise ValueError("Unmanifested backup files found")
    records = json.loads((bundle / "capture_index.json").read_text("utf-8"))
    report = reconcile(bundle / "files", records)
    if any(report[key] for key in ("missing", "mismatch", "unsafe")):
        raise ValueError("Backup images do not agree with database capture index")
    return manifest


def copy_tree(source, destination):
    # Reject links/junctions rather than copying data from outside the declared tree.
    for path in [source, *source.rglob("*")]:
        if path.is_symlink() or path.is_junction():
            raise ValueError(f"Linked directories/files are unsupported: {path}")
    shutil.copytree(source, destination)


def backup(args):
    source = args.storage_root.resolve()
    if not source.is_dir():
        raise ValueError("Storage root does not exist")
    copied_roots = [source / name for name in ("cattle", "sheep", "research")]
    copied_roots += [ROOT / name for name in ("species_configs", "business_configs", "security_configs")]
    if any(args.output.resolve().is_relative_to(path.resolve()) for path in copied_roots):
        raise ValueError("Backup output must be outside the directories being copied")
    args.output.mkdir(parents=True, exist_ok=False)
    was_running = bool(run(args.project, "ps", "-q", "--status", "running", "api", stdout=subprocess.PIPE).stdout.strip())
    try:
        if was_running:
            run(args.project, "stop", "api", stdout=subprocess.PIPE)
        records = capture_index(args.project)
        inspection = reconcile(source, records)
        if any(inspection[key] for key in ("missing", "mismatch", "unsafe")):
            raise ValueError("Resolve missing/corrupt/unsafe capture files before creating a backup")
        with (args.output / "database.dump").open("xb") as stream:
            run(args.project, "exec", "-T", "db", "pg_dump", "-U", "biolivestock", "-d", "biolivestock",
                "--format=custom", "--no-owner", "--no-acl", stdout=stream)
        (args.output / "capture_index.json").write_text(json.dumps(records, indent=2), "utf-8")
        (args.output / "files").mkdir()
        # Exclude backup/test/evidence trees; include reviewed research labels/crops.
        for folder in ("cattle", "sheep", "research"):
            if (source / folder).exists():
                copy_tree(source / folder, args.output / "files" / folder)
        for folder in ("species_configs", "business_configs", "security_configs"):
            copy_tree(ROOT / folder, args.output / "configs" / folder)
        manifest = {
            "version": 1, "created_at": datetime.now(UTC).isoformat(), "source_project": args.project,
            "schema_revision": query(args.project, "SELECT version_num FROM alembic_version"),
            "table_counts": counts(args.project), "reconciliation": inspection,
            "files": {file.relative_to(args.output).as_posix(): digest(file)
                      for file in sorted(args.output.rglob("*")) if file.is_file()},
        }
        (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2), "utf-8")
        verify_bundle(args.output)
    finally:
        if was_running:
            run(args.project, "start", "api", stdout=subprocess.PIPE)
    print(f"Verified backup: {args.output}. Copy this entire directory to a second drive.")


def restore(args):
    manifest = verify_bundle(args.bundle)
    name = args.target_database
    if not re.fullmatch(r"biolivestock_restore_[a-z0-9_]+", name):
        raise ValueError("Restore database must start biolivestock_restore_ and use lowercase letters/digits/underscores")
    if len(name) > 63 or query(args.project, f"SELECT 1 FROM pg_database WHERE datname='{name}'"):
        raise ValueError("Restore requires a new database name (maximum 63 characters)")
    if args.target_storage.exists():
        raise ValueError("Restore requires a new, absent storage directory")
    if args.target_storage.resolve().is_relative_to(args.bundle.resolve()):
        raise ValueError("Restore storage must be outside the backup bundle")
    # Never overwrite or switch the running application's database/storage.
    query(args.project, f'CREATE DATABASE "{name}"')
    with (args.bundle / "database.dump").open("rb") as stream:
        run(args.project, "exec", "-T", "db", "pg_restore", "-U", "biolivestock", "-d", name,
            "--no-owner", "--no-acl", "--exit-on-error", stdin=stream, stdout=subprocess.PIPE)
    copy_tree(args.bundle / "files", args.target_storage)
    if counts(args.project, name) != manifest["table_counts"]:
        raise ValueError("Restored table counts differ; clone retained for inspection")
    records = capture_index(args.project, name)
    expected = json.loads((args.bundle / "capture_index.json").read_text("utf-8"))
    if records != expected:
        raise ValueError("Restored capture index differs; clone retained for inspection")
    report = reconcile(args.target_storage.resolve(), records)
    if any(report[key] for key in ("missing", "mismatch", "unsafe")):
        raise ValueError("Restored files differ; clone retained for inspection")
    print(f"Verified isolated restore: database={name}, storage={args.target_storage}. Live configuration unchanged.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("backup", "verify", "restore", "reconcile"):
        command = commands.add_parser(name)
        if name != "verify":
            command.add_argument("--project", required=True)
        if name in ("backup", "reconcile"):
            command.add_argument("--storage-root", type=Path, required=True)
            command.add_argument("--output", type=Path, required=True)
        if name in ("verify", "restore"):
            command.add_argument("--bundle", type=Path, required=True)
        if name == "restore":
            command.add_argument("--target-database", required=True)
            command.add_argument("--target-storage", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "backup":
        backup(args)
    elif args.command == "restore":
        restore(args)
    elif args.command == "verify":
        verify_bundle(args.bundle)
        print("All backup checksums and capture files verified")
    else:
        report = reconcile(args.storage_root.resolve(), capture_index(args.project))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2)
        print(f"Read-only reconciliation: healthy={report['healthy']}; {args.output}")
        if not report["healthy"]:
            raise SystemExit(2)


if __name__ == "__main__":
    main()
