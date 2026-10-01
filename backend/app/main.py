from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.api.business import router as business_router
from app.api.routes import router
from app.api.valuation import router as valuation_router
from app.core.auth import load_credentials
from app.core.business_config import load_business_configs
from app.core.request_limits import RequestSizeLimit
from app.core.settings import get_settings
from app.core.species import load_species_configs
from app.services.detection import NoseDetector


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    app.state.settings = settings
    app.state.credentials = load_credentials(settings.auth_config_path)
    app.state.business_configs = load_business_configs(settings.business_config_dir)
    app.state.species_configs = load_species_configs(settings.species_config_dir)
    app.state.detector = NoseDetector(settings.model_root)
    settings.storage_root.mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(title="BioLivestock AI — Phase 1", version="0.1.0", lifespan=lifespan)
app.include_router(router)
app.include_router(business_router)
app.include_router(valuation_router)
app.add_middleware(RequestSizeLimit)


@app.exception_handler(RequestValidationError)
async def input_error(request, exc):
    # Do not echo secrets or non-finite input values in JSON validation failures.
    errors = [
        {key: value for key, value in error.items() if key in ("loc", "msg", "type")}
        for error in exc.errors()
    ]
    return JSONResponse({"detail": errors}, status_code=422)


@app.exception_handler(SQLAlchemyError)
async def database_error(request, exc):
    return JSONResponse({"detail": "Database operation unavailable"}, status_code=503)
