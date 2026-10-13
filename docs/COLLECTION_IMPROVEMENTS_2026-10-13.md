# Collection improvements — 2026-10-13

## Phone backup and recovery

Tap **Export phone backup** while capture/upload is idle. The app pauses those
operations, streams original images, immutable journals and upload receipts into
a ZIP, and verifies every SHA-256 before opening the native share sheet. Save a
copy outside the app (for example to the computer over USB). The temporary export
inside the app is not a durable second copy. All local operators/backends are
included; protect the ZIP because labels, GPS and operator IDs are sensitive.
Tokens and cached settings are excluded. Corrupt, orphan and partial queue files
are preserved for review rather than silently discarded. Originals are retained.

From the repository root on the computer:

```powershell
python tools/phone_backup.py verify --bundle 'D:\Backups\phone-backup.zip'
python tools/phone_backup.py extract --bundle 'D:\Backups\phone-backup.zip' --destination 'D:\Backups\recovered-NEW'
```

Use a new extraction directory. Verification rejects unsafe paths, links,
duplicate entries, missing/changed files and unsupported manifests. Extraction
does not upload, relabel, write to PostgreSQL or replace a live phone queue.
Retain the ZIP and extracted evidence until recovery is reviewed. Server backups
remain separate: [COLLECTION_RELIABILITY.md](COLLECTION_RELIABILITY.md).
Native sharing follows [share_plus documentation](https://pub.dev/packages/share_plus);
disk streaming uses [archive](https://pub.dev/packages/archive).

## Queue scale and screen boundaries

The host benchmark creates 1,800 synthetic 64 KiB payloads, not animal images.
An inventory plus at most 32 concurrent journal reads replaces sequential
per-file checks. No persistent metadata cache hides later corruption. Pending
captures and receipt review display 50 items per page; ordering and all
immutable IDs/labels remain intact.

| Windows host measurement | Baseline | Optimized |
| --- | ---: | ---: |
| First pending scan | 2,924 ms | 1,556 ms |
| Three warm scans | 2,256 / 1,798 / 2,110 ms | 1,102 / 1,011 / 1,052 ms |
| Whole-process peak RSS | 220,704,768 bytes | 254,394,368 bytes |

Median warm time improved about 50%; peak RSS did not decrease. These figures
include queue creation and Dart JIT overhead, and do not establish phone latency
or memory. Raw ignored evidence: `data/benchmarks/queue-{baseline,optimized}-20261013/results.json`.
The ZIP export verified all 3,600 files: 119,642,784 bytes, 38,153 ms and
373,665,792 bytes whole-process JIT peak RSS. A separate compiled Windows probe
took 29,081 ms with 140,767,232 bytes peak RSS for the same input. Python verified
the Dart ZIP and extracted all files into new `data/restores/phone-queue-20261013`.
This is host interoperability proof; field-sized photos/native sharing need a device.

Repeat into absent destinations from mobile/:

```powershell
dart run tool/benchmark_queue.dart ../data/benchmarks/queue-NEW
dart run tool/export_queue.dart ../data/benchmarks/queue-NEW/queue ../data/benchmarks/phone-NEW.zip
```

CaptureScreen has injected camera/location/filesystem/API boundaries while
production uses native plugins. Widget regressions exercise permission denial,
optional missing GPS, background/resume, offline restart, storage failure,
ZIP export, partial batch failure and pagination. Mocks establish screen behavior,
not physical plugin/device behavior.

## Dependency update policy

Docker pins Python/PostgreSQL image digests, apt package versions and the full
Linux amd64/CPython 3.12 CPU Python dependency closure. `requirements.in` records
direct ranges for intentional updates; `requirements.txt` pins direct
cross-platform dependencies; development tools also have tested version pins.
`requirements-docker.lock` is Linux-specific and
must not be installed into a Windows virtualenv. Docker runs `pip check`.
Only `opencv-python` is installed, following the package's
[one-distribution guidance](https://pypi.org/project/opencv-python/); both OpenCV
distributions previously shared `cv2`. This preserves the previous runtime's
actual OpenCV 5.0 while removing the conflict.

Use Flutter **3.47.5** (`mobile/.flutter-version`), Dart 3.13.4, exact direct pub
versions and committed `pubspec.lock`. Gradle/Kotlin/plugin versions remain
explicit; `kotlin.incremental=false` continues to address Windows cross-drive
cache roots. Resolve with `flutter pub get --enforce-lockfile`.

Pins prevent silent upgrades, not bit-for-bit APK determinism. Registry,
PyPI/CPU wheel and apt artifact availability is still required; unavailable
exact versions fail rather than silently upgrade. For intentional updates,
change relevant locks, build the image, run `pip check`, host suites, isolated
PostgreSQL upload/replay checks and Android build before committing new pins.
No detector weights are fetched or inferred.

## Research duplicate boundary

Reviewed imports retain byte hashes and reject repeated oriented RGB pixels
across lossless compression or EXIF rotation encodings. Diagnostics identify
both sample IDs. This detects exact decoded-image reuse, not near duplicates,
animal identity or independent ground-truth correctness. The frozen research
model/data requirements are unchanged; sheep remains disabled.

## Verification status

48 research tests and 64 Flutter host tests passed; Flutter analysis and Python
Ruff passed. Backend/tooling: 157 tests passed, then four additional archive
security guards passed (161 distinct cases; all 10 phone-backup tests passed).
The final Android debug APK built in 73.2 seconds after the initial native share
plugin build took 417.3 seconds. SHA-256:
`8d016a2caf30ef612c7be228dd7c120e8bb470473738b0c6925ae123e1d703d0`.
No API token is configured in that APK. Physical camera/GPS/share-sheet use,
large real photos and actual animal accuracy remain unverified.

The pinned image built successfully and `pip check` passed. All 63 Python package
versions, 40 apt versions and running image identity matched their pins; OpenCV
5.0.0 and CPU PyTorch 2.14.1 were imported successfully. The isolated stack
`biolivestock-reliability` on port 18001 had both services healthy. All 47
runtime source/config hashes matched. A synthetic JPEG upload passed server QC,
stored the image and PostgreSQL metadata with `pending_model`, and rejected blur
and invalid GPS without extra rows/files. Capture UUID:
`2d0d8a0a-3850-4dc9-b27e-d87203d4b380`. Four concurrent retries produced one
capture/receipt, with matching later replay, changed-payload 409, invalid-key 401
and wrong-operator 403. Evidence: `data/reliability/evidence/runtime-pins-20261013.json`,
`2d0d8a0a-3850-4dc9-b27e-d87203d4b380.json` and `idempotency-pins-20261013.json`.
Normal collection data/stack was not changed. These are synthetic/runtime checks,
not real animal validation.
Final reconciliation found 7 captures and no missing, mismatched, unsafe or orphan
files: `data/reliability/evidence/reconcile-pins-20261013.json`. Both isolated
test services are stopped; volumes, images, originals and evidence remain.

Local milestones: `fff4799` (research), `183341b` (phone export/scale/screen tests),
`001b9a2` (Windows path guard), `b6c4e0b` (verified build pins), followed by the
documentation commit. No new push. Physical-device and real-data gates are the
next work; this milestone does not authorize further model implementation.
