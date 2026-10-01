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

Sardorbek reported both Docker containers healthy and repeated HTTP 200 health checks in Docker Desktop. That is a manual report, not a new deployment run by the agent during this session. The tests above do not prove PostgreSQL runtime integration, Docker image rebuilding, crash recovery, farm-image quality, or real YOLO accuracy. Rebuild the backend image to use source changes:

```powershell
docker compose -f backend/docker-compose.yml up --build -d
```

End-to-end physical-device testing is paused indefinitely because Sardorbek's phone has water damage and is being dried/repaired. The committed `kotlin.incremental=false` Android setting remains in place. Successful Android rebuilding, camera/permission behavior, and mobile upload/persistence need verification when a repaired or replacement device is available. This external blocker does not prevent backend work. Read the root [PROGRESS.md](../PROGRESS.md) for current state and resume instructions.
