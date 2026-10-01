from datetime import UTC, datetime

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_session
from app.core.settings import get_settings
from app.core.species import Species, load_species_configs
from app.main import app


@pytest.fixture
def config():
    return load_species_configs(get_settings().species_config_dir)[Species.cattle]


@pytest.fixture
def sharp():
    return np.random.default_rng(7).integers(50, 201, (480, 640, 3), dtype=np.uint8)


@pytest.fixture
def jpeg(sharp):
    return cv2.imencode(".jpg", sharp)[1].tobytes()


@pytest.fixture
def metadata():
    return {
        "animal_id": "COW-001",
        "species": "cattle",
        "gps": {"latitude": 41.3, "longitude": 69.2},
        "timestamp": datetime.now(UTC).isoformat(),
        "operator_id": "operator-1",
    }


@pytest.fixture
def client(tmp_path):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine, expire_on_commit=False)

    def session_override():
        with sessions() as session:
            yield session

    app.dependency_overrides[get_session] = session_override
    with TestClient(app) as client:
        app.state.settings = get_settings().model_copy(update={"storage_root": tmp_path})
        yield client
    app.dependency_overrides.clear()
    engine.dispose()


@pytest.fixture
def db_session(client):
    # Inspect the same temporary database used by the API without real PostgreSQL.
    yield from app.dependency_overrides[get_session]()
