from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.core.settings import get_settings
from app.core.species import load_species_configs
from app.services.detection import NoseDetector


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    app.state.settings = settings
    app.state.species_configs = load_species_configs(settings.species_config_dir)
    app.state.detector = NoseDetector(settings.model_root)
    settings.storage_root.mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(title="BioLivestock AI — Phase 1", version="0.1.0", lifespan=lifespan)
app.include_router(router)
