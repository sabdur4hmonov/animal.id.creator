from pathlib import Path

from alembic.config import Config
from sqlalchemy import create_engine, inspect

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
