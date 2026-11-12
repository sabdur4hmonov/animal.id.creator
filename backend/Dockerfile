ARG BASE_RUNTIME_IMAGE=python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1
FROM ${BASE_RUNTIME_IMAGE}
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 YOLO_CONFIG_DIR=/tmp/ultralytics
WORKDIR /srv/backend
COPY backend/apt-packages.lock .
RUN apt-get update && tr -d '\r' < apt-packages.lock | xargs apt-get install -y --no-install-recommends && rm -rf /var/lib/apt/lists/*
COPY backend/requirements-docker.lock .
# CPU wheels keep Phase 1 usable without CUDA or a GPU.
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements-docker.lock && pip check
COPY backend/ .
COPY species_configs/ /srv/species_configs/
COPY business_configs/ /srv/business_configs/
COPY security_configs/ /srv/security_configs/
COPY tools/ /srv/tools/
ENV SPECIES_CONFIG_DIR=/srv/species_configs MODEL_ROOT=/srv STORAGE_ROOT=/srv/data
EXPOSE 8000
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
