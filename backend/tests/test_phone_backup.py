import hashlib
import json
import stat
from zipfile import ZipFile, ZipInfo

import pytest
from tools import phone_backup


def make_bundle(path, files=None, altered=False):
    files = files or {"queue/" + "a" * 32 + ".jpg": b"image",
                      "queue/entry-" + "a" * 32 + ".json": b"{corrupt preserved evidence"}
    manifest = {"version": 1, "format": "biolivestock-phone-queue", "files": {
        name: {"bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}
        for name, content in files.items()}}
    with ZipFile(path, "w") as archive:
        archive.writestr("manifest.json", json.dumps(manifest))
        for name, content in files.items():
            archive.writestr(name, b"wrong" if altered else content)
    return path


def test_verified_phone_backup_extracts_to_new_directory(tmp_path):
    bundle = make_bundle(tmp_path / "backup.zip")
    root = tmp_path / "new"
    result = phone_backup.extract(bundle, root)
    assert len(result["files"]) == 2
    assert (root / ("queue/entry-" + "a" * 32 + ".json")).read_bytes() == b"{corrupt preserved evidence"
    with pytest.raises(ValueError, match="absent"):
        phone_backup.extract(bundle, root)


def test_registry_journals_and_partial_receipts_are_retained(tmp_path):
    files = {
        "queue/registry-" + "a" * 32 + ".json": b"original immutable operation",
        "queue/registry-receipt-" + "a" * 32 + ".json.next": b"partial acknowledgement",
    }
    bundle = make_bundle(tmp_path / "registry.zip", files)
    result = phone_backup.extract(bundle, tmp_path / "restored")
    assert set(result["files"]) == set(files)
    for name, content in files.items():
        assert (tmp_path / "restored" / name).read_bytes() == content


@pytest.mark.parametrize("path", ["../outside", "queue/../outside", "queue/C:/secret", "queue/tokens.json"])
def test_phone_backup_rejects_unsafe_names(tmp_path, path):
    bundle = make_bundle(tmp_path / "backup.zip", {path: b"test"})
    with pytest.raises(ValueError, match="Unsafe"):
        phone_backup.verify(bundle)


def test_changed_phone_file_fails_verification(tmp_path):
    with pytest.raises(ValueError, match="checksum"):
        phone_backup.verify(make_bundle(tmp_path / "backup.zip", altered=True))


def test_duplicate_zip_entries_are_rejected(tmp_path):
    bundle = make_bundle(tmp_path / "backup.zip")
    with ZipFile(bundle, "a") as archive, pytest.warns(UserWarning, match="Duplicate"):
        archive.writestr("manifest.json", "{}")
    with pytest.raises(ValueError, match="Duplicate"):
        phone_backup.verify(bundle)


def test_unlisted_zip_file_is_rejected(tmp_path):
    bundle = make_bundle(tmp_path / "backup.zip")
    with ZipFile(bundle, "a") as archive:
        archive.writestr("unlisted", b"evidence not in manifest")
    with pytest.raises(ValueError, match="inventory"):
        phone_backup.verify(bundle)


def test_zip_symlink_is_rejected(tmp_path):
    name = "queue/" + "c" * 32 + ".jpg"
    content = b"/outside/target"
    info = ZipInfo(name)
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    bundle = tmp_path / "link.zip"
    with ZipFile(bundle, "w") as archive:
        archive.writestr(info, content)
        archive.writestr("manifest.json", json.dumps({"version": 1, "format": "biolivestock-phone-queue",
            "files": {name: {"bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}}}))
    with pytest.raises(ValueError, match="links"):
        phone_backup.verify(bundle)


def test_tampered_backup_never_creates_recovery_destination(tmp_path):
    bundle = make_bundle(tmp_path / "backup.zip", altered=True)
    destination = tmp_path / "recovery"
    with pytest.raises(ValueError, match="checksum"):
        phone_backup.extract(bundle, destination)
    assert not destination.exists()
