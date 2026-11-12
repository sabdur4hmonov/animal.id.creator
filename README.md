# Chorvam (BioLivestock AI)

Fresh-install offline cattle profiles, field collection and Android AR measurement: follow
[the Uzbek farm guide](docs/OFFLINE_FIELD_GUIDE.md). No API token/server is required
for provisional L- animals. **Scan animal** captures a quality-checked muzzle
photo, suggests local repeat candidates on Android, and lets the operator choose
an existing ID or create a new one. Open **My cattle** for photo and weight
history. Suggestions use the official OpenCV Android SDK's ORB features and
require human confirmation. The thresholds are experimental; field accuracy has
not been established. AR defaults to frozen left/right snapshots (four
simple body points each), with optional two-point front width. Snapshot requires
same-frame raw Depth/confidence; without front width it needs the median ratio
from at least three distinct same-species/breed animals measured in fast mode.
Point selection has undo/retake and mirrored original vector guides. Six-point
fast length/depth/width remains available with an
explicit uncalibrated Ramanujan ellipse girth; ordered closed 3D contours remain a
separate mode. Repeatability gates, both formula results, versioned local market
prices and optional minimum-10-distinct-animal scale correction are available.
Real phone/animal accuracy remains unverified; AR support must be checked on-device.
The existing authenticated backend/manual upload and calibrated_3d API stay intact.

The default muzzle capture is a configurable four-second camera burst: review
up to three sharp original-size JPEGs, then confirm each photo's animal separately.
No MP4 is saved. Unsupported/undersized streams fall back explicitly to single
photo capture. Profiles also collect left/right whole-body photos and link dated
actual scale observations within seven days; body photos do not enter muzzle
matching/checklists, and no photo-to-weight prediction is implemented.

Explicit profile/Tools registration freezes owner details and safely replays
L → permanent MAA issuance, then uploads derived original-byte muzzle journals.
Old L metadata is retained. Credentials for the original capture operator are
required; the public APK has no token. See the field guide for retry/ZIP steps.
[The pilot server plan](docs/PILOT_SERVER_PLAN.md) compares dated Uzbekistan
hosting prices and dated legal/security requirements; no public server is deployed.
The tested [HTTPS deployment runbook](docs/DEPLOY_RUNBOOK.md),
[five-role access guide](docs/ACCESS_ROLES.md) and
[truthful pitch status](docs/STATUS_FOR_PITCH.md) describe the prepared pilot kit.

Native AR rendering is original Kotlin/OpenGL using pinned official
`com.google.ar:core:1.54.0`; no unlicensed renderer was copied. Google's
[official sample source license](https://github.com/google-ar/arcore-android-sdk/blob/v1.54.0/LICENSE)
is Apache-2.0, with **separate binary/AAR terms** in
[ARCore Additional Terms](https://developers.google.com/ar/develop/terms).
See [NOTICE](NOTICE) for sources/license distinctions. No Cloud/Geospatial service.

Cattle data collection API: native camera capture, image quality feedback, optional YOLOv8n muzzle cropping, filesystem images and PostgreSQL metadata. Sheep configuration exists but is disabled. Authenticated registration/status controls, exact-image reuse review and immutable scan provenance are available. Offline cattle embedding/matching experiments are in `research/`; they do not provide validated production identity decisions. Public/cloud deployment and CI/CD are not implemented; an isolated local HTTPS pilot kit is tested.

## Run the backend

Offline collection/retries and backup/restore commands: [COLLECTION_RELIABILITY.md](docs/COLLECTION_RELIABILITY.md).
Phone ZIP recovery, queue benchmark and dependency pins: [collection improvements](docs/COLLECTION_IMPROVEMENTS_2026-10-13.md).
Mobile screen design, visual previews and UI checks: [MOBILE_DESIGN.md](docs/MOBILE_DESIGN.md).
Permanent MAA-series issuance, ownership transfers, death/slaughter archives and report lookup: [ANIMAL_REGISTRY.md](docs/ANIMAL_REGISTRY.md).
Latest completed fixes, verification and remaining data/device gates: [MVP completion audit](docs/MVP_COMPLETION_2026-10-14.md).
Four offline UI languages/scripts and Unicode field behavior: [LANGUAGES.md](docs/LANGUAGES.md).

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

Android has two build flavors: `prod` (default; existing package/data/signature)
and `demo` (`ai.biolivestock.biolivestock_capture.demo`, **Chorvam NAMUNA**).
Demo holds six original schematic animals in its own app sandbox and
`demo_capture_queue`; it never reads the regular queue. Every route retains a
sample disclosure. It is a read-only presentation, without camera/AR/clinical
actions or invented weights. The demo manifest removes INTERNET and ApiClient
also blocks network calls even if credentials were supplied accidentally.

```powershell
cd 'D:\Coding projects\moliddetector\mobile'
flutter run --flavor prod
flutter run --flavor demo
# Build/archive separately without connecting or installing on a phone:
cd ..
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
./tools/build_mobile_release.ps1 -Flavor prod -Milestone chorvam-prod-my-review
./tools/build_mobile_release.ps1 -Flavor demo -Milestone chorvam-demo-my-review
```

Use a new milestone name each time. APK/SHA-256/manifest/signer evidence stays
under ignored `data/artifacts/`. The script checks the existing project's signer,
package/version and opposite network permissions. No install/uninstall occurs.
These remain development-signed pilot APKs, not a Play Store release-signing setup.
The first-run four-language guide can be replayed from **Tools → Field guide**.

**Offline farm collection (2026-11-04):** a fresh token-free install now includes
verified YAML defaults. Set an offline operator in Tools, create a clearly
temporary `L-…` animal, record six muzzle views and export originals plus CSV
ledgers. Gallery copies go to the BioLivestock album; originals survive permission
failure. Provisional labels never allocate MAA IDs or auto-upload. Existing
authenticated server-ID collection remains available. See
[offline field instructions](docs/OFFLINE_FIELD_GUIDE.md). The online commands below
remain for authenticated backend operations; an initial connection is no longer
required for local provisional collection.

Install Flutter 3.47.5 (Dart 3.13.4), Android Studio/Android SDK or Xcode for iOS, and confirm `flutter doctor`. The scaffold was generated for Android and iOS; gallery selection and desktop/web capture are intentionally absent. Android requires API 24+ and iOS 13+.

```powershell
cd 'D:\Coding projects\moliddetector\mobile'
flutter pub get --enforce-lockfile
adb reverse tcp:8000 tcp:8000
$localKeys = Get-Content '../backend/.secrets/tokens.json' -Raw | ConvertFrom-Json
flutter run --flavor prod --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define="API_TOKEN=$($localKeys.operator.token)" --dart-define="OPERATOR_ID=$($localKeys.operator.operator_id)"
```

Phone testing targets a physical Android phone connected over USB (USB debugging enabled). Latest-build physical-device verification is unverified: the current backlog explicitly excludes installation/device interaction. Earlier founder/device reports are historical; no Android emulator is used for this milestone. `adb reverse tcp:8000 tcp:8000` forwards the phone's port 8000 to the backend on this computer, so the app reaches it at `http://127.0.0.1:8000` with no LAN IP or firewall rule. Re-run `adb reverse` whenever the phone is reconnected or adb restarts (`adb reverse --list` shows active rules). Always pass the `--dart-define` above: the fallback in `mobile/lib/api_client.dart` is still the emulator address `10.0.2.2`, which does not work on a real phone. Without USB, a phone on the same trusted LAN can use the computer's LAN IP instead (for example `http://192.168.1.20:8000`, with port 8000 allowed through the firewall). For iOS Simulator use `http://127.0.0.1:8000`. Local HTTP is allowed for development by the platform manifests. iOS must be built/run on macOS. The offline home uses bundled verified rules without a backend. The legacy authenticated capture tools need a reachable backend to fetch live species rules.

Default UI is Uzbek Latin. In **Vositalar / Воситалар / Инструменты / Tools**, choose **Til / yozuv / Язык / Language** to select Uzbek Latin, Uzbek Cyrillic, Russian or English; the choice persists offline. The following button names use English. Names and notes accept Unicode; permanent IDs/reference codes retain Latin ASCII.

Enter the animal ID, position one muzzle fully within the frame, and tap Capture; the operator comes from the configured key. Camera permission and optional GPS are requested; missing GPS stays null. Local-QC-passing photos are saved to a durable phone queue before **Saved on this phone** appears. In these legacy authenticated tools, after one connection caches species settings, capture can continue offline. The default provisional field collection already has bundled defaults. **Next capture (saved locally)** retains the image; restart recovers pending uploads. Reconnect and upload individually or use **Upload pending captures**. Stable request keys make retries safe even if a response was lost after persistence. Server QC/framing remains authoritative. **Review saved upload receipts** shows UUID/file-path mappings for the ledger. Originals/receipts are retained locally; do not clear app data/uninstall before upload and backup. See [collection reliability](docs/COLLECTION_RELIABILITY.md) for pre-trip testing and recovery.

## Models and species configuration

For a new animal, connect once and choose **New animal ID** (or Animals →
**Register new animal**), enter its owner and use the server-issued `MAA00000001`
style number. Keep that number on the tag/ledger and use it for every photo and
owner change. Existing legacy IDs remain valid; never invent an M/MAA-series number.
Animals offers owner transfers and death/slaughter reports, retained archives and
abattoir record lookup. A recorded slaughter report is not physical/biometric proof.
Back up before upgrading the backend; startup applies additive Alembic 0005.

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

See `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` and `docs/VALIDATION.md` for design, scope and checks. Origin points to `https://github.com/sabdur4hmonov/animal.id.creator.git`. The audit repairs were published to `main` on 2026-10-13 at Sardorbek's explicit request. Pushes require an explicit user request and are never automatic.

See `docs/PHASE2_RESEARCH.md` for offline extraction/matching commands and `docs/DATA_REQUIREMENTS.md` for the data gates for later phases. The 2026-11-10 updates were not installed/tested on a phone, by request. Sardorbek reports his 23117RA68G does not support ARCore; ordinary capture/side-photo collection remains the intended non-AR path. Only two cattle were properly tried on 2026-11-06, with motion/sharpness difficulties and no measured accuracy percentage.

See [SECURITY_AND_REGISTRY.md](docs/SECURITY_AND_REGISTRY.md) for operator/admin keys, status/review endpoints, immutable provenance, duplicate-check boundaries and rotation. Existing keys are preserved by initialization; run it only once. Protected endpoints fail closed when credentials are missing. Only the health endpoint and API documentation are public.

See [WEIGHT_AND_VALUATION.md](docs/WEIGHT_AND_VALUATION.md) for deterministic adult-cattle formulas, calibrated 3D measurement inputs, configured carcass-yield scenarios and admin price updates. Prices start unset. Formula arithmetic is tested; real-world accuracy remains unverified.

See [ANTI_SPOOF_GROUNDWORK.md](docs/ANTI_SPOOF_GROUNDWORK.md) for advisory Moiré/reflection/rectangle signals, Android root/emulator hints and mock-GPS plausibility checks. These do not return a live/genuine verdict. Breathing/micro-movement stays blocked on labeled videos; current device behavior remains unverified.
