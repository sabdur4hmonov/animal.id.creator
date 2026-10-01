# Phase 1 validation

## Backend checks (2026-10-01)

From the repository root, with backend development dependencies installed:

```powershell
Set-Location backend
..\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider
..\.venv\Scripts\python.exe -m ruff check . --no-cache
```

The backend suite passes **51 tests**. It uses temporary SQLite databases and image files, synthetic images, and explicit detector doubles. The Alembic test upgrades an empty temporary database, checks the schema against SQLAlchemy metadata, and downgrades it. No real checkpoint or mobile device is used.

Coverage includes successful pending-model and mocked-crop collection, GPS/UTC-date handling, invalid metadata and non-finite coordinates, byte/pixel limits, blur and exposure rejection, clipping preserved across blur-analysis sizes, crop/model failures, storage/database failure cleanup, EXIF orientation, invalid image decoding, health failures, and finite species configuration.

Server exposure statistics now use the original decoded grayscale pixels. Blur still uses the configured analysis size. This prevents resizing from averaging away clipped shadows/highlights. Mobile QC remains advisory and may disagree with server rejection; the server response is authoritative. Thresholds and scores remain heuristics and require calibration on real cattle images.

## Runtime verification boundaries

On 2026-10-01 the agent built and ran an isolated Docker stack on port 18000, uploaded a real 2816×2120 cattle-nose JPEG, and independently checked the HTTP 201 response, passed QC, PostgreSQL row/config provenance, `pending_model` status with null crop/detection, and the saved JPEG. Container and host SHA-256 hashes matched. A flat/blurry JPEG and NaN GPS were rejected with HTTP 422 and left no extra files or rows. Both verification containers were healthy. Source hashes confirmed the image included the latest backend hardening.

Evidence is retained in ignored `data/verification/evidence/24510aa3-f88a-43d8-aeeb-46efa72e4d19.json`; the capture UUID is the same. Image attribution is in [SAMPLE_MEDIA.md](SAMPLE_MEDIA.md). The verification stack has a separate Compose project/database volume and `data/verification` storage, so test samples stay separate from normal collection. This proves the Phase 1 HTTP → QC → filesystem → PostgreSQL path, not crash recovery, farm-image calibration or real YOLO inference.

To reproduce using a quality-approved local JPEG, run from the project root:

```powershell
$env:API_PORT='18000'
$env:STORAGE_DIRECTORY='../data/verification'
docker compose -p biolivestock-verification -f backend/docker-compose.yml up --build -d
.\.venv\Scripts\python.exe tools/verify_docker_upload.py --image data/verification-inputs/cow-nose.jpg
```

The verifier preserves test records/files and writes JSON evidence for every successful run. It also refuses an outdated backend image. Default Compose port/storage remain 8000 and data/ when those variables are unset. To rebuild the normal backend in a fresh terminal:

```powershell
docker compose -f backend/docker-compose.yml up --build -d
```

End-to-end physical-device testing is paused indefinitely because Sardorbek's phone has water damage and is being dried/repaired. The committed `kotlin.incremental=false` Android setting remains in place. Successful Android rebuilding, camera/permission behavior, and mobile upload/persistence need verification when a repaired or replacement device is available. This external blocker does not prevent backend or research work. Read the root [PROGRESS.md](../PROGRESS.md) for current state and resume instructions.
