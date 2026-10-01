import hashlib
import json
from types import SimpleNamespace

import pytest

from app.core.auth import Principal, load_credentials
from app.main import app
from app.services.integrity import verify_stored_image
from tests.test_api import post


def test_credentials_missing_and_distinct_principals(tmp_path):
    path = tmp_path / "keys.json"
    assert load_credentials(path) == []
    entry = {"operator_id": "operator-1", "role": "operator", "token_sha256": "a" * 64}
    path.write_text(json.dumps([entry, entry]), encoding="utf-8")
    with pytest.raises(ValueError, match="Duplicate"):
        load_credentials(path)
    path.write_text(json.dumps([entry, {**entry, "operator_id": "operator-2"}]), encoding="utf-8")
    with pytest.raises(ValueError, match="distinct API key"):
        load_credentials(path)


def test_operator_capture_access_and_admin_integrity(client, metadata, jpeg):
    response = post(client, metadata, jpeg).json()
    app.state.credentials.append(
        Principal(
            operator_id="operator-2", role="operator", token_sha256=hashlib.sha256(b"test-second").hexdigest()
        )
    )
    assert (
        client.get(
            f"/api/v1/captures/{response['id']}", headers={"Authorization": "Bearer test-second"}
        ).status_code
        == 404
    )
    route = f"/api/v1/admin/captures/{response['id']}/integrity"
    assert client.get(route).status_code == 403
    admin = {"Authorization": "Bearer test-admin"}
    assert client.get(route, headers=admin).json()["status"] == "matched"
    path = app.state.settings.storage_root / response["file_path"]
    path.write_bytes(b"synthetic tamper in disposable test storage")
    assert client.get(route, headers=admin).json()["status"] == "mismatch"
    path.unlink()  # Only this pytest tmp_path fixture, never user data.
    assert client.get(route, headers=admin).json()["status"] == "missing"


def test_legacy_and_path_escape_are_not_attested(tmp_path):
    legacy = SimpleNamespace(id="legacy", stored_sha256=None, file_path="old.jpg")
    assert verify_stored_image(tmp_path, legacy)["status"] == "unavailable_legacy"
    legacy.stored_sha256 = "a" * 64
    legacy.file_path = "../escape.jpg"
    assert verify_stored_image(tmp_path, legacy)["status"] == "unsafe_path"
