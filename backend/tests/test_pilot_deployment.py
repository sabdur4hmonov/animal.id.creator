import io
import json
import secrets
from argparse import Namespace
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from tools import init_pilot_secrets, pilot_backup, pilot_monitor

from production_entrypoint import configure


def test_pilot_secrets_are_new_random_files_and_never_overwrite(tmp_path):
    root = tmp_path / "secrets"
    init_pilot_secrets.initialize(root, "SYNTHETIC")
    before = {f.name: f.read_bytes() for f in root.iterdir()}
    with pytest.raises(FileExistsError):
        init_pilot_secrets.initialize(root, "SYNTHETIC")
    assert before == {f.name: f.read_bytes() for f in root.iterdir()}
    raw = json.loads((root / "tokens.json").read_text())
    hashes = json.loads((root / "api_keys.json").read_text())
    import hashlib

    assert {p["token_sha256"] for p in hashes} == {
        hashlib.sha256(v["token"].encode()).hexdigest() for v in raw.values()
    }
    assert raw["operator"]["token"] != raw["admin"]["token"]
    init_pilot_secrets.initialize(tmp_path / "original", "PILOT", operator_id="ORIGINAL-OFFLINE")
    preserved = json.loads((tmp_path / "original/tokens.json").read_text())
    assert preserved["operator"]["operator_id"] == "ORIGINAL-OFFLINE"


def test_production_entrypoint_fails_closed_on_missing_or_external_secret_and_proxy(tmp_path):
    file = tmp_path / "dsn"
    value = "postgresql+psycopg://biolivestock:" + secrets.token_urlsafe(24) + "@db:5432/biolivestock"
    file.write_text(value)
    base = {
        "DATABASE_URL_FILE": str(file),
        "FORWARDED_ALLOW_IPS": "172.30.42.10",
        "PUBLIC_ORIGIN": "https://localhost:18443",
    }
    valid = base.copy()
    assert configure(valid) == "172.30.42.10" and "DATABASE_URL" not in valid
    for edits in (
        {"DATABASE_URL_FILE": ""},
        {"FORWARDED_ALLOW_IPS": "*"},
        {"PUBLIC_ORIGIN": "http://localhost"},
        {"PUBLIC_ORIGIN": "https://user:pass@example.invalid"},
    ):
        environment = base | edits
        with pytest.raises(ValueError):
            configure(environment)
        assert "DATABASE_URL" not in environment
    for wrong in (value.replace("@db:", "@outside.invalid:"), value + "?host=outside.invalid"):
        file.write_text(wrong)
        with pytest.raises(ValueError):
            configure(base.copy())


def test_independent_cli_settings_load_database_secret_file_without_password_environment(tmp_path):
    from app.core.settings import Settings

    file = tmp_path / "dsn"
    value = "postgresql+psycopg://biolivestock:" + secrets.token_urlsafe(24) + "@db:5432/biolivestock"
    file.write_text(value)
    settings = Settings(database_url_file=file)
    assert settings.database_url == value


def backup_args(tmp_path):
    source = tmp_path / "storage"
    source.mkdir()
    return Namespace(
        storage_root=source,
        backup_root=tmp_path / "backups",
        restore_root=tmp_path / "clones",
        min_free_gib=1,
        compose_file=tmp_path / "compose.yml",
        env_file=None,
        project="synthetic",
    )


def test_scheduled_backup_refuses_nested_data_roots_and_preserves_somebody_elses_lock(tmp_path, monkeypatch):
    args = backup_args(tmp_path)
    monkeypatch.setattr(
        pilot_backup.subprocess, "run", lambda *a, **kw: pytest.fail("No container may be touched")
    )
    with pytest.raises(ValueError, match="separate"):
        pilot_backup.run_backup(Namespace(**(vars(args) | {"backup_root": args.storage_root / "backups"})))
    args.backup_root.mkdir()
    lock = args.backup_root / ".backup-running"
    lock.write_text("another process")
    monkeypatch.setattr(pilot_backup.shutil, "disk_usage", lambda _: SimpleNamespace(free=20 * 1024**3))
    with pytest.raises(FileExistsError):
        pilot_backup.run_backup(args)
    assert lock.read_text() == "another process"


def test_monitor_reports_stale_missing_backup_disk_and_health_without_credentials(tmp_path, monkeypatch):
    args = Namespace(
        url="https://localhost/health",
        ca_file=None,
        disk_root=tmp_path,
        backup_root=tmp_path,
        project="synthetic",
        min_free_gib=1,
        max_backup_age_hours=26,
    )
    monkeypatch.setattr(
        pilot_monitor.urllib.request,
        "urlopen",
        lambda *a, **kw: io.BytesIO(b'{"status":"ok","database":"ok"}'),
    )
    monkeypatch.setattr(pilot_monitor.shutil, "disk_usage", lambda _: SimpleNamespace(free=20 * 1024**3))
    assert pilot_monitor.inspect(args)["problems"] == ["verified_backup_age"]
    receipt = {
        "project": "synthetic",
        "restore_verified": True,
        "live_promoted": False,
        "verified_at": (datetime.now(UTC) - timedelta(hours=1)).isoformat(),
    }
    path = tmp_path / "synthetic-verified.json"
    path.write_text(json.dumps(receipt))
    assert pilot_monitor.inspect(args)["healthy"] is True
    receipt["verified_at"] = (datetime.now(UTC) - timedelta(hours=30)).isoformat()
    path.write_text(json.dumps(receipt))
    assert "verified_backup_age" in pilot_monitor.inspect(args)["problems"]
    monkeypatch.setattr(pilot_monitor.shutil, "disk_usage", lambda _: SimpleNamespace(free=0))
    assert "disk_space" in pilot_monitor.inspect(args)["problems"]
    monkeypatch.setattr(pilot_monitor.urllib.request, "urlopen", lambda *a, **kw: io.BytesIO(b"[]"))
    assert "https_health" in pilot_monitor.inspect(args)["problems"]
    for url in (
        "http://localhost/health",
        "https://user:pass@localhost/health",
        "https://localhost/health?key=x",
    ):
        with pytest.raises(ValueError, match="credential-free"):
            pilot_monitor.inspect(Namespace(**(vars(args) | {"url": url})))
