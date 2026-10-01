# BioLivestock AI — project progress

Last live repository inspection: 2026-10-01, Asia/Tashkent. Project root: D:\Coding projects\moliddetector. Read this file and inspect the live repository at the start of the next session. Distinguish direct checks from Sardorbek's reports.

## Current stop point

**Physical mobile testing is paused indefinitely.** Sardorbek's test phone has water damage and is being dried/repaired. End-to-end camera → local QC → upload verification is blocked until a repaired or replacement device is available. This is an external device blocker, not a code issue; do not wait for it to continue backend work. The Android cross-drive build fix, `kotlin.incremental=false`, is in place and committed. A successful build after that fix and the mobile flow are still unverified.

Completed independent work on 2026-10-01: hardened Phase 1 backend exposure/validation and expanded tests from 25 to 51. The HTTP upload → QC → saved JPEG → PostgreSQL path is now independently verified in an isolated Docker stack with a real cattle photograph. The latest user mandate authorizes continuing through the roadmap beyond Phase 1; the earlier Phase-1-only restriction is superseded. Next: offline cattle embedding/matching evaluation tools, keeping production collection stable and sheep disabled. No biometric accuracy can be established without a curated multi-animal, multi-session dataset.

The live D: repository now has the local initial commit `f2b8698` and the intended origin. The tracked Android Gradle file already contains the Kotlin setting. This agent did not push. The separate recovery bundle commit `6dda7a5` remains distinct from this repository.

## Live Git evidence from the D: project

Checked live on 2026-10-01. The working tree was clean at session entry. This log is a snapshot before committing this session's backend/documentation changes. `git log --oneline -20` returned:

```text
28ec11d Document project state and Windows Kotlin build fix
f2b8698 Initial commit: Phase 1 scaffold
```

`git remote -v` returned:

```text
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

The initial commit, origin, root PROGRESS.md and node_modules ignore rule are already present. Do not redo initialization or import the separate recovery bundle. This session's changes are confined to backend source/tests and progress/validation documentation. Local commits are allowed; pushing still requires Sardorbek's review. Refresh live Git evidence in the next session rather than assuming this snapshot is the latest HEAD.

## Implemented and verification level

- Backend source contains FastAPI health/species/capture endpoints, OpenCV blur/lighting checks, SQLAlchemy metadata, Alembic migration, local image storage, and Docker Compose with PostgreSQL. **51 backend tests passed and Ruff passed on 2026-10-01.** Tests use temporary SQLite and synthetic images/model doubles; they do not establish PostgreSQL runtime integration or real model accuracy.
- **Docker/PostgreSQL verified by the agent on 2026-10-01:** built latest source in a separate `biolivestock-verification` stack on port 18000; uploaded a real cattle-nose JPEG; confirmed passed QC, HTTP 201, saved normalized JPEG, matching host/container SHA-256, PostgreSQL metadata/config snapshot and `pending_model` with null crop/detection. Blurry image and NaN GPS requests returned 422 without extra files/records. Normal containers were already healthy at inspection, consistent with Sardorbek's earlier visual report.
- Flutter camera app source is scaffolded for live preview, capture, local QC, metadata and backend upload. The committed cross-drive compiler setting is in place. Successful rebuilding, launch, camera/permissions and end-to-end upload remain unverified; physical testing is externally blocked by the unavailable water-damaged phone. Mobile source/build configuration was not changed this session.
- YOLO wrapper and species-aware configuration are present, but there is **no cattle muzzle checkpoint** and no real inference verified. Quality-approved original images therefore use crop_status=pending_model and crop_path=null. Do not fabricate a crop.
- Cattle is enabled and sheep disabled. Both use the same species schema and YAML pattern for model path, crop parameters, and quality thresholds. Adding sheep later should use its config/model rather than separate processing branches. The Phase 1–5 scope is in docs/ROADMAP.md.
- A separate recovery bundle and staged initial commit 6dda7a5182f2f83cc2d8445221df7263ed58098f exist under the Codex outputs/work area. That commit is **not in the live D: repository**, whose initial commit is f2b8698. Do not import the bundle over current work.

## Key Decisions & Config

- Phase 1 has no YOLO checkpoint. Preserve quality-approved originals with crop_status=pending_model and crop_path=null; do not fabricate a muzzle crop.
- Species configuration is YAML-driven: cattle enabled, sheep disabled, with per-species model and crop parameters.
- Server QC is authoritative. Exposure histograms use original decoded grayscale pixels; only blur analysis is resized. Mobile first-pass checks may disagree with server clipping rejection. No thresholds were changed without farm-image calibration.
- Species configuration rejects NaN/infinite numbers at validation time. Metadata errors omit raw input values so invalid GPS values still receive a serializable HTTP 422 response.
- Existing mobile test setup uses a physical Android phone over USB; no emulator is configured. Do not create an emulator as a substitute without a new user request. Backend work proceeds independently while the phone is unavailable.
- **Windows cross-drive Kotlin build:** the project is on D: while Flutter Pub/Gradle caches can live on C:. Kotlin incremental compilation tried to make a relative path across those roots and crashed with “this and base files have different roots.” In mobile/android/gradle.properties, keep `kotlin.incremental=false`. Kotlin documents this as the supported JVM incremental-compilation switch (https://kotlinlang.org/docs/gradle-compilation-and-caches.html); the same cross-drive failure appears in Flutter’s issue tracker (https://github.com/flutter/flutter/issues/187658). Moving PUB_CACHE or Gradle caches to D: is machine-specific and does not make the checked-in project portable. This flag trades faster incremental Kotlin recompilation for a stable build until a confirmed upstream fix is adopted. The new build has not yet been run successfully.

## Settled decisions and next check

Phase 1 collects cattle camera images and structured metadata. The latest mandate authorizes later roadmap phases where data/device prerequisites permit; do not build sheep models/crop branches, push, spend money, or use external credentials without approval. Server QC is authoritative; mobile QC is advisory. GPS can be null. Animal IDs are operator-supplied labels. Uploads are not automatically retried or deduplicated. Research results must not be treated as validated identity/liveness/weight evidence.

Backend upload verification is complete. The separate project volume and `data/verification` keep test samples apart from normal collection. Capture/evidence UUID: `24510aa3-f88a-43d8-aeeb-46efa72e4d19`. Evidence JSON: `data/verification/evidence/24510aa3-f88a-43d8-aeeb-46efa72e4d19.json`. Both containers were healthy; source hashes matched host code. Samples and evidence are retained. Reproducible script: tools/verify_docker_upload.py; instructions and media attribution are in docs/VALIDATION.md and docs/SAMPLE_MEDIA.md. Default Compose settings are unchanged; optional API_PORT/STORAGE_DIRECTORY support isolated runs. The normal previously running API is not assumed rebuilt by this verification.

Resume mobile only when Sardorbek has a repaired or replacement device. Discover its actual device ID; do not assume 23117RA68G still applies. From mobile/, run `flutter clean`, `flutter pub get`, `adb -s <device-id> reverse tcp:8000 tcp:8000`, then `flutter run -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000`. The app's fallback 10.0.2.2 address is for an emulator. Verify camera, permissions, QC, retake and upload plus pending_model persistence. There is no required architectural decision blocking independent backend work.

## Backend hardening completed — 2026-10-01

- Reproduced two clipping regressions, six non-finite GPS error-response failures, and an accepted infinite blur threshold before fixing them. Lighting now counts original pixels rather than resized averages; API metadata rejection no longer echoes invalid raw numbers; species config requires finite numeric values.
- Added rejection-path assertions for malformed metadata, no/multiple detected muzzles, unavailable models and poor crops; confirmed no image or capture row is created. Added partial crop-write failure cleanup, database health failure, nullable GPS/UTC storage dates, EXIF orientation, BGR decoding, unsupported/truncated image rejection, and Alembic upgrade/schema comparison/downgrade tests.
- Baseline: 25 tests passed. Final: **51 passed**, using `..\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider` from backend/. Ruff: `..\.venv\Scripts\python.exe -m ruff check . --no-cache` passed. One upstream TestClient/httpx deprecation warning remains; dependencies were not changed. Cache disabling avoids an existing local pytest cache access warning.
- Added docs/VALIDATION.md, which README already referenced, with runnable commands and the limits of this evidence. Scores remain heuristics; no real cattle image calibration, YOLO inference, Docker/PostgreSQL runtime upload, or mobile build is claimed.
