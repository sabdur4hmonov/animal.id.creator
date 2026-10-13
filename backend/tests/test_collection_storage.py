import hashlib
import json
from argparse import Namespace
from types import SimpleNamespace

import pytest
from tools import collection_storage as storage


def test_read_only_reconciliation_reports_missing_changed_orphan_and_legacy_files(tmp_path):
    root = tmp_path / "data"
    (root / "cattle/A").mkdir(parents=True)
    good = root / "cattle/A/good.jpg"
    good.write_bytes(b"original")
    changed = root / "cattle/A/changed.jpg"
    changed.write_bytes(b"changed")
    orphan = root / "cattle/A/orphan.jpg"
    orphan.write_bytes(b"orphan")
    records = [
        {"id": "good", "file_path": "cattle/A/good.jpg", "stored_sha256": storage.digest(good)},
        {"id": "bad", "file_path": "cattle/A/changed.jpg", "stored_sha256": hashlib.sha256(b"before").hexdigest()},
        {"id": "missing", "file_path": "cattle/A/missing.jpg"},
        {"id": "unsafe", "file_path": "../secret.jpg"},
    ]
    before = {path: path.read_bytes() for path in root.rglob("*") if path.is_file()}
    report = storage.reconcile(root, records)
    assert report["missing"] == ["cattle/A/missing.jpg"]
    assert report["mismatch"] == ["cattle/A/changed.jpg"]
    assert report["orphans"] == ["cattle/A/orphan.jpg"]
    assert report["unsafe"][0]["id"] == "unsafe"
    assert not report["healthy"]
    assert before == {path: path.read_bytes() for path in root.rglob("*") if path.is_file()}
    legacy = storage.reconcile(root, [{"id": "old", "file_path": "cattle/A/good.jpg"}])
    assert legacy["hash_unavailable"] == ["cattle/A/good.jpg"]


@pytest.mark.parametrize("relative", ["../secret", "C:/secret", "folder\\secret", "/secret"])
def test_paths_cannot_escape(tmp_path, relative):
    with pytest.raises(ValueError):
        storage.contained(tmp_path, relative)


@pytest.fixture
def bundle(tmp_path):
    (tmp_path / "files/cattle/A").mkdir(parents=True)
    image = tmp_path / "files/cattle/A/original.jpg"
    image.write_bytes(b"evidence")
    records = [{"id": "capture", "file_path": "cattle/A/original.jpg", "stored_sha256": storage.digest(image)}]
    (tmp_path / "capture_index.json").write_text(json.dumps(records), "utf-8")
    (tmp_path / "database.dump").write_bytes(b"PGDMP-placeholder")
    manifest = {"version": 1, "files": {file.relative_to(tmp_path).as_posix(): storage.digest(file)
                for file in tmp_path.rglob("*") if file.is_file()}}
    (tmp_path / "manifest.json").write_text(json.dumps(manifest), "utf-8")
    return tmp_path


def test_bundle_detects_corruption_and_extra_files(bundle):
    assert storage.verify_bundle(bundle)["version"] == 1
    extra = bundle / "extra.txt"
    extra.write_text("unknown")
    with pytest.raises(ValueError, match="Unmanifested"):
        storage.verify_bundle(bundle)
    extra.unlink()
    (bundle / "database.dump").write_bytes(b"corrupt")
    with pytest.raises(ValueError, match="checksum"):
        storage.verify_bundle(bundle)


@pytest.mark.parametrize("failure", ["unsafe_name", "existing_database", "existing_storage", "nested_storage"])
def test_restore_rejects_overwrites_before_create_or_restore(bundle, monkeypatch, failure):
    target = bundle.parent / (bundle.name + "_restore")
    name = "biolivestock_restore_test"
    queries = []

    def query(*args):
        queries.append(args[1])
        return "1" if failure == "existing_database" else ""

    monkeypatch.setattr(storage, "query", query)
    if failure == "unsafe_name":
        name = "biolivestock"
    elif failure == "existing_storage":
        target = bundle
    elif failure == "nested_storage":
        target = bundle / "new_directory"
    with pytest.raises(ValueError):
        storage.restore(Namespace(bundle=bundle, project="test", target_database=name, target_storage=target))
    assert all(sql.startswith("SELECT") for sql in queries)


def test_backup_refuses_recursive_destination_before_touching_docker(tmp_path):
    source = tmp_path / "data"
    source.mkdir()
    with pytest.raises(ValueError, match="outside"):
        storage.backup(Namespace(storage_root=source, output=source / "research/backup", project="test"))


@pytest.mark.parametrize("running", [True, False])
def test_failed_backup_restores_original_api_state(tmp_path, monkeypatch, running):
    source = tmp_path / "data"
    source.mkdir()
    actions = []

    def run(project, *args, **kwargs):
        actions.append(args[0])
        return SimpleNamespace(stdout=b"container" if running else b"")

    def fail(*args):
        raise RuntimeError("database failure")

    monkeypatch.setattr(storage, "run", run)
    monkeypatch.setattr(storage, "capture_index", fail)
    monkeypatch.setattr(storage, "validate_storage_mount", lambda *_: None)
    with pytest.raises(RuntimeError, match="database failure"):
        storage.backup(Namespace(storage_root=source, output=tmp_path / "backup", project="test"))
    assert actions == (["ps", "stop", "start"] if running else ["ps"])


def test_wrong_project_storage_pair_is_rejected(tmp_path, monkeypatch):
    monkeypatch.setattr(storage, "run", lambda *args, **kwargs: SimpleNamespace(stdout=b"container"))
    mounts = [{"Mounts": [{"Destination": "/srv/data", "Type": "bind", "Source": str(tmp_path / "correct")}]}]
    monkeypatch.setattr(storage.subprocess, "run", lambda *args, **kwargs:
                        SimpleNamespace(stdout=json.dumps(mounts).encode()))
    storage.validate_storage_mount("test", tmp_path / "correct")
    with pytest.raises(ValueError, match="does not match"):
        storage.validate_storage_mount("test", tmp_path / "wrong")


@pytest.mark.parametrize("name", ["crop.jpg", "scans.csv", "original.jpg"])
@pytest.mark.parametrize("fault", ["changed", "missing", "extra"])
def test_restore_checks_every_copied_file(tmp_path, monkeypatch, name, fault, capsys):
    bundle = tmp_path / "bundle"
    files = bundle / "files"
    files.mkdir(parents=True)
    for relative in ("crop.jpg", "scans.csv", "original.jpg"):
        (files / relative).write_bytes(relative.encode())
    (bundle / "database.dump").write_bytes(b"synthetic dump")
    (bundle / "capture_index.json").write_text("[]", "utf-8")
    manifest = {"version": 1, "table_counts": {}, "files": {
        file.relative_to(bundle).as_posix(): storage.digest(file)
        for file in bundle.rglob("*") if file.is_file()}}
    (bundle / "manifest.json").write_text(json.dumps(manifest), "utf-8")
    copy = storage.copy_tree

    def bad_copy(source, target):
        copy(source, target)
        if fault == "missing":
            (target / name).unlink()
        elif fault == "changed":
            (target / name).write_bytes(b"changed")
        else:
            (target / "unexpected.txt").write_bytes(b"extra")

    monkeypatch.setattr(storage, "copy_tree", bad_copy)
    monkeypatch.setattr(storage, "query", lambda *_: "")
    monkeypatch.setattr(storage, "run", lambda *_, **__: None)
    monkeypatch.setattr(storage, "counts", lambda *_: {})
    monkeypatch.setattr(storage, "capture_index", lambda *_: [])
    with pytest.raises(ValueError, match="Restored"):
        storage.restore(Namespace(bundle=bundle, project="test", target_database="biolivestock_restore_test",
                                  target_storage=tmp_path / "restored"))
    assert "Verified isolated restore" not in capsys.readouterr().out
