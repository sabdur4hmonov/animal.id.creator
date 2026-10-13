from pathlib import Path

import pytest
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.exc import IntegrityError

from alembic import command
from app.core.settings import get_settings


def test_registry_migration_preserves_legacy_and_guards_counters_history(tmp_path, monkeypatch):
    url = f"sqlite:///{(tmp_path / 'registry.sqlite').as_posix()}"
    monkeypatch.setenv("DATABASE_URL", url)
    get_settings.cache_clear()
    config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    engine = create_engine(url)
    try:
        command.upgrade(config, "0004")
        with engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO animals VALUES ('cattle','LEGACY-1','insured',1,CURRENT_TIMESTAMP,'operator-1')"
                )
            )
        command.upgrade(config, "head")
        with engine.begin() as connection:
            assert (
                connection.execute(text("SELECT status FROM animals WHERE animal_id='LEGACY-1'")).scalar_one()
                == "insured"
            )
            connection.execute(text("INSERT INTO animal_number_counters VALUES ('M',1)"))
            connection.execute(
                text("INSERT INTO animal_profiles VALUES ('cattle','LEGACY-1',NULL,'active','null',NULL)")
            )
            connection.execute(
                text("INSERT INTO registry_receipts VALUES ('operator-1','abcdefghijklmnop','hash','{}')")
            )
            connection.execute(text("UPDATE animal_number_counters SET last_number=2 WHERE prefix='M'"))
            connection.execute(
                text("UPDATE animal_profiles SET lifecycle='deceased' WHERE animal_id='LEGACY-1'")
            )
        for statement in [
            "UPDATE animal_number_counters SET last_number=1",
            "DELETE FROM animal_number_counters",
            "UPDATE animal_profiles SET lifecycle='active'",
            "DELETE FROM animal_profiles",
            "UPDATE registry_receipts SET response='{}'",
            "DELETE FROM registry_receipts",
        ]:
            with pytest.raises(IntegrityError), engine.begin() as connection:
                connection.execute(text(statement))
        command.check(config)
    finally:
        engine.dispose()
        get_settings.cache_clear()
