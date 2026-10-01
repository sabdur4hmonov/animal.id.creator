from pathlib import Path

import pytest
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import IntegrityError

from alembic import command
from app.core.settings import get_settings


def test_migration_matches_models_and_can_be_reversed(tmp_path, monkeypatch):
    # API tests use create_all; exercise Docker's Alembic path separately.
    url = f"sqlite:///{(tmp_path / 'migrations.sqlite').as_posix()}"
    monkeypatch.setenv("DATABASE_URL", url)
    get_settings.cache_clear()
    config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    engine = create_engine(url)
    try:
        command.upgrade(config, "head")
        assert "captures" in inspect(engine).get_table_names()
        command.check(config)
        command.downgrade(config, "base")
        assert "captures" not in inspect(engine).get_table_names()
    finally:
        engine.dispose()
        get_settings.cache_clear()


def test_legacy_capture_survives_and_raw_evidence_changes_are_blocked(tmp_path, monkeypatch):
    url = f"sqlite:///{(tmp_path / 'legacy.sqlite').as_posix()}"
    monkeypatch.setenv("DATABASE_URL", url)
    get_settings.cache_clear()
    config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    engine = create_engine(url)
    try:
        command.upgrade(config, "0001")
        with engine.begin() as connection:
            connection.execute(
                text("""INSERT INTO captures
                (id, animal_id, species, gps, timestamp, operator_id, image_quality_score,
                 file_path, crop_status, quality, config_version, config_snapshot)
                VALUES ('legacy', 'OLD-1', 'cattle', :gps,
                        '2025-01-01', 'old-operator', 0.8, 'old.jpg', 'pending_model', '{}', 1, '{}')"""),
                {"gps": '{"latitude":41,"longitude":69}'},
            )
        command.upgrade(config, "head")
        with engine.connect() as connection:
            row = connection.execute(text("SELECT * FROM captures WHERE id='legacy'")).mappings().one()
            assert row["operator_id"] == "old-operator" and row["received_at"] is None
            animal = connection.execute(text("SELECT * FROM animals")).mappings().one()
            assert animal["status"] == "open" and animal["registered_by"] is None
        for statement in ("UPDATE captures SET operator_id='fake'", "DELETE FROM captures"):
            with pytest.raises(IntegrityError, match="append-only"), engine.begin() as connection:
                connection.execute(text(statement))
        command.check(config)
    finally:
        engine.dispose()
        get_settings.cache_clear()
