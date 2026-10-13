import hashlib
import json
import sqlite3

import pytest
from sqlalchemy import func, select

from app.core.auth import Principal
from app.main import app
from app.models.capture import Capture
from app.models.upload_receipt import UploadReceipt
from app.services import storage
from app.services.detection import DetectionUnavailable

KEY = "a" * 32


def send(client, metadata, jpeg, key=KEY):
    return client.post(
        "/api/v1/captures",
        headers={"Idempotency-Key": key},
        data={"metadata": json.dumps(metadata)},
        files={"image": ("capture.jpg", jpeg, "image/jpeg")},
    )


def test_retry_returns_original_response_without_rerunning_model(client, metadata, jpeg, db_session, monkeypatch):
    first = send(client, metadata, jpeg)
    assert first.status_code == 201
    monkeypatch.setattr(app.state.detector, "detect", lambda *_: (_ for _ in ()).throw(DetectionUnavailable()))
    retry = send(client, metadata, jpeg)
    assert retry.status_code == 201
    assert retry.json() == first.json()
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 1
    assert db_session.scalar(select(func.count()).select_from(UploadReceipt)) == 1
    assert len(list(app.state.settings.storage_root.rglob("*.jpg"))) == 1


@pytest.mark.parametrize("change", ["image", "animal", "gps", "time"])
def test_changed_payload_conflicts(client, metadata, jpeg, db_session, change):
    assert send(client, metadata, jpeg).status_code == 201
    if change == "image":
        jpeg += b"new bytes"
    elif change == "animal":
        metadata["animal_id"] = "OTHER"
    elif change == "gps":
        metadata["gps"] = None
    else:
        metadata["timestamp"] = "2026-10-08T00:00:00Z"
    assert send(client, metadata, jpeg).status_code == 409
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 1


def test_failed_request_does_not_consume_key(client, metadata, jpeg, db_session):
    assert send(client, metadata, b"invalid").status_code == 422
    assert db_session.scalar(select(func.count()).select_from(UploadReceipt)) == 0
    assert send(client, metadata, jpeg).status_code == 201


def test_replay_still_requires_authenticated_operator(client, metadata, jpeg):
    assert send(client, metadata, jpeg).status_code == 201
    client.headers["Authorization"] = "Bearer test-admin"
    assert send(client, metadata, jpeg).status_code == 403


def test_keys_are_scoped_to_operator_not_shared_across_principals(client, metadata, jpeg, db_session):
    first = send(client, metadata, jpeg).json()
    app.state.credentials.append(Principal(operator_id="operator-2", role="operator",
                                           token_sha256=hashlib.sha256(b"second").hexdigest()))
    client.headers["Authorization"] = "Bearer second"
    metadata["operator_id"] = "operator-2"
    second = send(client, metadata, jpeg)
    assert second.status_code == 201
    assert second.json()["id"] != first["id"]
    assert db_session.scalar(select(func.count()).select_from(UploadReceipt)) == 2


@pytest.mark.parametrize("key", ["short", "x" * 129, "a/b" * 8])
def test_invalid_key_does_not_save(client, metadata, jpeg, key):
    assert send(client, metadata, jpeg, key).status_code == 422
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


def test_lost_commit_ack_keeps_committed_evidence_and_replays(client, metadata, jpeg, db_session, monkeypatch):
    dialect = db_session.get_bind().dialect
    real_commit = dialect.do_commit
    failed = False

    def lost_ack(connection):
        nonlocal failed
        real_commit(connection)
        if not failed:
            failed = True
            raise sqlite3.OperationalError("Simulated lost COMMIT acknowledgement")

    monkeypatch.setattr(dialect, "do_commit", lost_ack)
    assert send(client, metadata, jpeg).status_code == 503
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 1
    assert db_session.scalar(select(func.count()).select_from(UploadReceipt)) == 1
    record = db_session.scalar(select(Capture))
    assert (app.state.settings.storage_root / record.file_path).is_file()
    retried = send(client, metadata, jpeg)
    assert retried.status_code == 201
    assert retried.json()["id"] == record.id
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 1


@pytest.mark.parametrize("fault", ["missing", "changed"])
def test_replay_refuses_missing_or_changed_original(client, metadata, jpeg, fault):
    first = send(client, metadata, jpeg).json()
    path = app.state.settings.storage_root / first["file_path"]
    if fault == "missing":
        path.unlink()
    else:
        path.write_bytes(b"corrupt evidence")
    assert send(client, metadata, jpeg).status_code == 503


def test_file_fsync_failure_never_commits_capture(client, metadata, jpeg, db_session, monkeypatch):
    def failed_sync(*_):
        raise OSError("Simulated disk flush failure")

    monkeypatch.setattr(storage.os, "fsync", failed_sync)
    assert send(client, metadata, jpeg).status_code == 503
    assert db_session.scalar(select(func.count()).select_from(Capture)) == 0
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))
