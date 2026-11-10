import hashlib
import json
import stat
from zipfile import ZipFile, ZipInfo

import pytest
from tools import phone_backup


def make_bundle(path, files=None, altered=False):
    files = files or {
        "queue/" + "a" * 32 + ".jpg": b"image",
        "queue/entry-" + "a" * 32 + ".json": b"{corrupt preserved evidence",
    }
    manifest = {
        "version": 1,
        "format": "biolivestock-phone-queue",
        "files": {
            name: {"bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}
            for name, content in files.items()
        },
    }
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


def test_field_ledger_and_unicode_sidecars_restore_without_new_registration(tmp_path):
    files = {
        "queue/field-animal-" + "b" * 32 + ".json": '{"version":1,"tag":"Ғулом"}'.encode(),
        "queue/field-scan-" + "c" * 32 + ".json": b'{"version":1,"view":"front1"}',
        "ledger/roster.csv": "label,tag\r\nL-ABC,Ғулом\r\n".encode(),
        "ledger/scans.csv": b"label,view\r\nL-ABC,front1\r\n",
    }
    bundle = make_bundle(tmp_path / "field.zip", files=files)
    recovered = tmp_path / "recovered"
    phone_backup.extract(bundle, recovered)
    for name, content in files.items():
        assert (recovered / name).read_bytes() == content


def test_side_photo_and_registration_ledgers_restore_with_immutable_evidence(tmp_path):
    files = {
        "queue/field-measurement-" + "d" * 32 + ".json": b'{"record_type":"server_mapping"}',
        "ledger/side_photos.csv": b"label,side,scale_kg\r\nL-SYNTHETIC,left,400\r\n",
        "ledger/registrations.csv": b"local_label,animal_id\r\nL-SYNTHETIC,MAA00000001\r\n",
        "ledger/registered_uploads.csv": b"local_label,source_scan_key\r\nL-SYNTHETIC,fixture\r\n",
    }
    recovered = tmp_path / "new-ledger-restore"
    phone_backup.extract(make_bundle(tmp_path / "new-ledgers.zip", files=files), recovered)
    assert {name: (recovered / name).read_bytes() for name in files} == files


@pytest.mark.parametrize(
    "name", ["ledger/../tokens.json", "queue/field-preferences.json", "ledger/settings.csv"]
)
def test_field_ledger_allowlist_rejects_secrets_and_escapes(tmp_path, name):
    bundle = make_bundle(tmp_path / "bad-field.zip", files={name: b"private"})
    with pytest.raises(ValueError, match="Unsafe"):
        phone_backup.verify(bundle)


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
        archive.writestr(
            "manifest.json",
            json.dumps(
                {
                    "version": 1,
                    "format": "biolivestock-phone-queue",
                    "files": {name: {"bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}},
                }
            ),
        )
    with pytest.raises(ValueError, match="links"):
        phone_backup.verify(bundle)


def test_tampered_backup_never_creates_recovery_destination(tmp_path):
    bundle = make_bundle(tmp_path / "backup.zip", altered=True)
    destination = tmp_path / "recovery"
    with pytest.raises(ValueError, match="checksum"):
        phone_backup.extract(bundle, destination)
    assert not destination.exists()
