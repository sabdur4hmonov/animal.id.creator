# BioLivestock AI — project progress

Last live repository inspection: 2026-09-30, Asia/Tashkent. Project root: D:\Coding projects\moliddetector. Read this file and inspect the live repository at the start of the next session. Distinguish direct checks from Sardorbek's reports.

## Current stop point

The Flutter Android build on Sardorbek's physical device **23117RA68G** over USB with **adb reverse** failed in Kotlin incremental compilation with “this and base files have different roots.” A persistent Gradle setting has now been added. The next action is to run flutter clean, flutter pub get, and flutter run for that device, then verify camera → local QC → upload and the backend's pending_model record. The build and end-to-end flow are not yet confirmed.

The live D: repository now has the local initial commit `f2b8698` and the intended origin. The tracked Android Gradle file already contains the Kotlin setting. This agent did not push. The separate recovery bundle commit `6dda7a5` remains distinct from this repository.

## Live Git evidence from the D: project

Checked on 2026-09-30 after the Android Gradle setting was saved. This is a snapshot before this root progress update and the node_modules ignore edit are committed. `git log --oneline -20` returned:

```text
f2b8698 Initial commit: Phase 1 scaffold
```

`git remote -v` returned:

```text
origin  https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin  https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

`git status --short` at this snapshot showed the modified root .gitignore and untracked root PROGRESS.md. The .gitignore edit adds node_modules/. Those two changes can be committed locally; this recorded log is the pre-documentation snapshot. Refresh the log in this file at a later checkpoint. The initial commit was made in the live D: repository and origin/main was the tracked branch at inspection. This agent did not push.

## Implemented and verification level

- Backend source contains FastAPI health/species/capture endpoints, quality checks using OpenCV blur and brightness, SQLAlchemy metadata, Alembic migration, local image storage, and Docker Compose with PostgreSQL. Earlier D: source tests recorded **25 passing backend tests** and Ruff checks. These tests were not rerun during this session.
- **Sardorbek manually verified the Docker stack in Docker Desktop**: both containers healthy and the health endpoint repeatedly returned HTTP 200. This is his visual report, not a Docker run independently witnessed by this agent. A real upload through the running stack and its PostgreSQL/file persistence still need confirmation.
- Flutter camera app source is scaffolded for live preview, capture, local QC, metadata and backend upload. The Android build failed in Kotlin incremental compilation across C:/D: paths; the project setting below has been applied but not yet verified by a new build. Launch, camera operation, permissions, and end-to-end upload remain unverified.
- YOLO wrapper and species-aware configuration are present, but there is **no cattle muzzle checkpoint** and no real inference verified. Quality-approved original images therefore use crop_status=pending_model and crop_path=null. Do not fabricate a crop.
- Cattle is enabled and sheep disabled. Both use the same species schema and YAML pattern for model path, crop parameters, and quality thresholds. Adding sheep later should use its config/model rather than separate processing branches. The Phase 1–5 scope is in docs/ROADMAP.md.
- A separate recovery bundle and staged initial commit 6dda7a5182f2f83cc2d8445221df7263ed58098f exist under the Codex outputs/work area. That commit is **not in the live D: repository**, whose initial commit is f2b8698. Do not import the bundle over current work.

## Key Decisions & Config

- Phase 1 has no YOLO checkpoint. Preserve quality-approved originals with crop_status=pending_model and crop_path=null; do not fabricate a muzzle crop.
- Species configuration is YAML-driven: cattle enabled, sheep disabled, with per-species model and crop parameters.
- **Windows cross-drive Kotlin build:** the project is on D: while Flutter Pub/Gradle caches can live on C:. Kotlin incremental compilation tried to make a relative path across those roots and crashed with “this and base files have different roots.” In mobile/android/gradle.properties, keep `kotlin.incremental=false`. Kotlin documents this as the supported JVM incremental-compilation switch (https://kotlinlang.org/docs/gradle-compilation-and-caches.html); the same cross-drive failure appears in Flutter’s issue tracker (https://github.com/flutter/flutter/issues/187658). Moving PUB_CACHE or Gradle caches to D: is machine-specific and does not make the checked-in project portable. This flag trades faster incremental Kotlin recompilation for a stable build until a confirmed upstream fix is adopted. The new build has not yet been run successfully.

## Settled decisions and next check

Phase 1 collects cattle camera images and structured metadata only. Matching, vector search, liveness, weight/valuation, B2B, sheep activation, auth, cloud deployment and CI/CD are later work. Server QC is authoritative; mobile QC is advisory. GPS can be null. Animal IDs are operator-supplied labels. Uploads are not automatically retried or deduplicated.

From the mobile directory, run `flutter clean`, `flutter pub get`, `adb reverse tcp:8000 tcp:8000`, then `flutter run -d 23117RA68G --dart-define=API_BASE_URL=http://127.0.0.1:8000`. The mobile default `http://10.0.2.2:8000` is for an Android emulator; the physical USB device needs localhost through adb reverse. Verify live preview, capture, local QC, retake and upload, then confirm the API response and saved image/metadata show pending_model. If the build still fails, capture the new error before changing versions or paths. The initial Git commit and remote are now present. No further product decision is needed for the build verification.
