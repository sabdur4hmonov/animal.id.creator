# Phase 1 validation

## Backend checks (2026-10-01)

From the repository root, with backend development dependencies installed:

```powershell
Set-Location backend
..\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider
..\.venv\Scripts\python.exe -m ruff check . --no-cache
```

The initial hardening suite passed **51 tests**; final extensions below bring the backend count to 97. Tests use temporary SQLite databases/image files, synthetic images and detector doubles. Alembic upgrades/checks/reverses temporary schemas. No real checkpoint or mobile device is used.

Coverage includes successful pending-model and mocked-crop collection, GPS/UTC-date handling, invalid metadata and non-finite coordinates, byte/pixel limits, blur and exposure rejection, clipping preserved across blur-analysis sizes, crop/model failures, storage/database failure cleanup, EXIF orientation, invalid image decoding, health failures, and finite species configuration.

Server exposure statistics now use the original decoded grayscale pixels. Blur still uses the configured analysis size. This prevents resizing from averaging away clipped shadows/highlights. Mobile QC remains advisory and may disagree with server rejection; the server response is authoritative. Thresholds and scores remain heuristics and require calibration on real cattle images.

## Runtime verification boundaries

On 2026-10-01 the agent built and ran an isolated Docker stack on port 18000, uploaded a real 2816×2120 cattle-nose JPEG, and independently checked the HTTP 201 response, passed QC, PostgreSQL row/config provenance, `pending_model` status with null crop/detection, and the saved JPEG. Container and host SHA-256 hashes matched. A flat/blurry JPEG and NaN GPS were rejected with HTTP 422 and left no extra files or rows. Both verification containers were healthy. Source hashes confirmed the image included the latest backend hardening.

Evidence is retained in ignored `data/verification/evidence/24510aa3-f88a-43d8-aeeb-46efa72e4d19.json`; the capture UUID is the same. Image attribution is in [SAMPLE_MEDIA.md](SAMPLE_MEDIA.md). The verification stack has a separate Compose project/database volume and `data/verification` storage, so test samples stay separate from normal collection. This proves the Phase 1 HTTP → QC → filesystem → PostgreSQL path, not crash recovery, farm-image calibration or real YOLO inference.

After verification, the normal backend was rebuilt with the same current sources and returned HTTP 200 with database ok. Its source hashes matched the tested code. The separate verification containers were stopped; their database volume, image and evidence were preserved.

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

End-to-end physical-device testing is paused indefinitely while Sardorbek's phone is repaired. The Kotlin cross-drive fix now has a successful Android debug build (below). Camera/permission/GPS and mobile upload/persistence still need a repaired/replacement device. Read [PROGRESS.md](../PROGRESS.md) for current state and resume instructions.

## Offline research verification (2026-10-01)

Combined backend/research tests: **82 passed** (51 backend, 31 research); Ruff passed for backend/research/tools. Command: `.\.venv\Scripts\python.exe -m pytest -c research/pyproject.toml backend/tests research/tests -q -p no:cacheprovider` from the repository root. Real CPU feature extraction with official checksum-verified weights produced 512-dimensional vectors and repeat cosine 1.0, with networking disabled. Evidence: `data/research/resnet18-smoke.json`. Unit tests and a one-image extraction smoke check do not validate biometric accuracy. [PHASE2_RESEARCH.md](PHASE2_RESEARCH.md) describes the labeled-data protocol and commands.

## Authenticated registry extension (2026-10-01)

Backend suite now passes 59 tests. Migration tests include a pre-existing 0001 capture surviving the additive 0002 upgrade, registry backfill and raw-SQL mutation rejection. Actual Docker/PostgreSQL checks passed with operator/admin keys: real JPEG upload (`65a9351f-ded9-42dd-a248-827d97da7af4.json`) and synthetic registry/admin/exact-replay/immutability checks (`controls-d53b4892-0a8b-47c9-8309-90dfd636769e.json`) under data/verification/evidence. Run `tools/init_local_credentials.py` once before the Docker commands above; the upload verifier reads the ignored local token file without printing secrets. `tools/verify_controls_docker.py` repeats control checks and retains synthetic records/evidence.

## Formula and market-rate extension (2026-10-01)

Backend suite: 81 passed, including formula/yield/Decimal rounding, calibrated mock 3D geometry, rejected invalid/ambiguous inputs, role checks and price-history conflicts. Migration 0003 was applied and actual Docker/PostgreSQL synthetic market update/valuation endpoints passed; evidence: data/verification/evidence/controls-6a7d65ab-0056-47dd-896a-31cc0902bf6c.json. No animal accuracy or real market-rate validity was tested.

## Final independent checks (2026-10-01)

- 128 Python tests passed (97 backend + 31 research), with one known upstream TestClient/httpx deprecation warning. Ruff passed for backend/research/tools. Tests add synthetic Fourier/glare/rectangle controls, mock/root/emulator/location/time anomalies, strict telemetry validation, capture ownership and stored-file integrity detection. No new embedding feature was added.
- Flutter analyze --no-pub passed; flutter test --no-pub passed all 7 host tests. flutter build apk --debug --no-pub compiled successfully with the Kotlin flag, Flutter 3.47.5 / Dart 3.13.4 / Gradle 9.3.1. APK is under ignored mobile/build/app/outputs/flutter-apk/app-debug.apk; it contains no configured API token. Device behavior is unverified.
- Actual latest real-image Docker upload/file/DB/source-hash evidence: data/verification/evidence/7fe42c24-4353-4df4-9b7a-38b1a2e44b7a.json. Synthetic advisory/price/status review: controls-e8cfbb7e-baf6-4d41-b1cb-022704f61261.json in that folder. PostgreSQL concurrency/integrity: concurrency-65781f3d-2672-49f4-becb-78dd5e6114f1.json. Concurrent exact scans yielded match counts [0,1], status edits [200,409], price edits [201,409], and stored-file hash matched.
- Normal backend migrated to 0003 and is healthy on 8000: health 200/database ok, authenticated species 200, anonymous species 401, all 43 backend/migration/species/business/security config hashes match. Normal capture count preserved at 0; normal price remains unset. Pre-rollout SQL backup retained at data/backups/20261001-211413/pre-controls.sql. Synthetic samples/prices remain isolated; verification containers stopped with their volume/evidence retained.

Reproduce controls in the isolated stack after the commands above with `tools/verify_controls_docker.py` and `tools/verify_concurrency_docker.py` using the repository Python environment. They create and retain synthetic evidence. Anti-spoof flags are advisory/unvalidated, formula math is not measured animal accuracy, and immutable client GPS is not verified GPS.
