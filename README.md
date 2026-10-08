# BioLivestock AI — Phase 1

Cattle data collection API: native camera capture, image quality feedback, optional YOLOv8n muzzle cropping, filesystem images and PostgreSQL metadata. Sheep configuration exists but is disabled. Authenticated registration/status controls, exact-image reuse review and immutable scan provenance are available. Offline cattle embedding/matching experiments are in `research/`; they do not provide validated production identity decisions. Cloud deployment and CI/CD are not implemented.

## Run the backend

Offline collection/retries and backup/restore commands: [COLLECTION_RELIABILITY.md](docs/COLLECTION_RELIABILITY.md).

Install Docker Desktop and start its Linux container engine. From PowerShell:

```powershell
cd 'D:\Coding projects\moliddetector'
python tools/init_local_credentials.py
cd 'D:\Coding projects\moliddetector\backend'
docker compose up --build
```

Legacy `docker-compose up --build` works too. Compose starts PostgreSQL, waits for it to be healthy, applies Alembic migrations, then serves the API on port 8000. The first build downloads CPU PyTorch and Ultralytics dependencies and may take several minutes. No GPU is required.

- Health: http://localhost:8000/health
- Interactive API: http://localhost:8000/docs
- Configs: http://localhost:8000/api/v1/species
- Upload: `POST /api/v1/captures` with multipart `image` and JSON-string `metadata`.

Images persist in the repository's ignored `data/` folder. PostgreSQL persists in a Docker named volume. `docker compose down` stops services without deleting that volume. Do not use `down -v` if you want to retain metadata.

## Run the mobile app

Install stable Flutter (Dart 3.10+), Android Studio/Android SDK or Xcode for iOS, and confirm `flutter doctor`. The scaffold was generated for Android and iOS; gallery selection and desktop/web capture are intentionally absent. Android requires API 24+ and iOS 13+.

```powershell
cd 'D:\Coding projects\moliddetector\mobile'
flutter pub get
adb reverse tcp:8000 tcp:8000
$localKeys = Get-Content '../backend/.secrets/tokens.json' -Raw | ConvertFrom-Json
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define="API_TOKEN=$($localKeys.operator.token)" --dart-define="OPERATOR_ID=$($localKeys.operator.operator_id)"
```

Phase 1 testing is done on a physical Android phone connected over USB (USB debugging enabled); no Android emulator is set up or used. `adb reverse tcp:8000 tcp:8000` forwards the phone's port 8000 to the backend on this computer, so the app reaches it at `http://127.0.0.1:8000` with no LAN IP or firewall rule. Re-run `adb reverse` whenever the phone is reconnected or adb restarts (`adb reverse --list` shows active rules). Always pass the `--dart-define` above: the fallback in `mobile/lib/api_client.dart` is still the emulator address `10.0.2.2`, which does not work on a real phone. Without USB, a phone on the same trusted LAN can use the computer's LAN IP instead (for example `http://192.168.1.20:8000`, with port 8000 allowed through the firewall). For iOS Simulator use `http://127.0.0.1:8000`. Local HTTP is allowed for development by the platform manifests. iOS must be built/run on macOS. Start the backend before opening the app so it can fetch species rules.

Enter animal and operator IDs, position one muzzle fully within the frame, and tap Capture. The app requests camera permission and optionally obtains a GPS fix at capture time. Denied or unavailable location is stored as null. Inspect the captured image and local sharpness/lighting feedback, then upload or retake. Local checks run on the device; the backend repeats authoritative QC and applies detection/crop checks if weights exist. The app displays the server crop status and keeps a failed upload available for manual retry during the current session. It has no durable offline queue. A network timeout can occur after server persistence, so check metadata before retrying a potentially completed upload.

## Models and species configuration

No trained cattle muzzle checkpoint was supplied. This repository therefore starts in useful collection mode: quality-approved originals are saved with `crop_status=pending_model` and `crop_path=null`. It does **not** pretend a center crop or a full cow box is a detected nose.

Place a trusted, custom-trained **YOLOv8n detection checkpoint** at `models/cattle/yolov8n-muzzle.pt`, trained with class name `muzzle`, or edit `species_configs/cattle.yaml` to match your checkpoint path and class. Binary weights are ignored by Git. The detector activates on subsequent uploads when the file is present; restart the backend after config changes. Wrong class names or invalid weights return 503. No muzzle, multiple muzzles, poor framing or failed crop QC return 422. Existing pending samples are not automatically reprocessed.

Both YAMLs hold the same model, crop and quality structure. To add sheep later, supply its weights, calibrate its config and enable it; application code and database already carry `species` throughout. Thresholds are first-pass heuristics and need validation against real farm captures.

## Upload example

In the API docs, click Authorize with your operator bearer token, then supply an image and this JSON in the `metadata` field. The operator_id must match that credential:

```json
{
  "animal_id": "COW-001",
  "species": "cattle",
  "gps": {"latitude": 41.3, "longitude": 69.2},
  "timestamp": "2026-09-29T09:00:00+05:00",
  "operator_id": "operator-1"
}
```

Timestamp must include its timezone. Use `gps: null` when no fix exists. Animal IDs contain 1–64 ASCII letters, digits, underscores or hyphens, starting with a letter/digit; Windows reserved filenames are rejected. Images must be JPEG/PNG, at most 15 MiB and 25 million decoded pixels by default. Responses return QC measurements, an original path, and optional crop path/detection provenance. `image_quality_score` is a heuristic, not an identity confidence. Server status codes: 201 saved, 413 too large, 422 invalid metadata/image/QC/framing, 503 database/storage/model unavailable.

## Tests and development

```powershell
cd 'D:\Coding projects\moliddetector'
python -m venv .venv
.\.venv\Scripts\python -m pip install -r backend/requirements-dev.txt
cd backend
..\.venv\Scripts\python -m pytest -q
..\.venv\Scripts\ruff check .
cd ../mobile
flutter analyze
flutter test
```

For a non-Docker backend, provide a running PostgreSQL instance, copy `backend/.env.example` to `backend/.env` and adjust its connection string, then run `alembic upgrade head` followed by `uvicorn app.main:app --reload` from `backend/` using the virtual environment. Compose's database is deliberately not published on the host. Tests use temporary SQLite metadata storage and injected model doubles; they do not measure a real trained detector's accuracy.

See `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` and `docs/VALIDATION.md` for design, scope and checks. The initial commit is local and origin points to `https://github.com/sabdur4hmonov/animal.id.creator.git`. Nothing is pushed automatically.

See `docs/PHASE2_RESEARCH.md` for offline extraction/matching commands and `docs/DATA_REQUIREMENTS.md` for the data gates for later phases. Physical-phone testing is currently paused because the device is being repaired; backend and offline tools proceed independently.

See [SECURITY_AND_REGISTRY.md](docs/SECURITY_AND_REGISTRY.md) for operator/admin keys, status/review endpoints, immutable provenance, duplicate-check boundaries and rotation. Existing keys are preserved by initialization; run it only once. Protected endpoints fail closed when credentials are missing. Only the health endpoint and API documentation are public.

See [WEIGHT_AND_VALUATION.md](docs/WEIGHT_AND_VALUATION.md) for deterministic adult-cattle formulas, calibrated 3D measurement inputs, configured carcass-yield scenarios and admin price updates. Prices start unset. Formula arithmetic is tested; real-world accuracy remains unverified.

See [ANTI_SPOOF_GROUNDWORK.md](docs/ANTI_SPOOF_GROUNDWORK.md) for advisory Moiré/reflection/rectangle signals, Android root/emulator hints and mock-GPS plausibility checks. These do not return a live/genuine verdict. Breathing/micro-movement stays blocked on labeled videos and physical-device testing on the repaired phone.
