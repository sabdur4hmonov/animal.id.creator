# Code audit and repair plan — 2026-10-13

**Repair follow-up:** all eight confirmed findings below are now implemented and verified.
See [AUDIT_REPAIRS_2026-10-13.md](AUDIT_REPAIRS_2026-10-13.md) for current behavior,
regression/integration evidence and remaining empirical limits. The observations, source
line locations and diagnostic probes below describe the original audited revision.

Audited application revision: `d99c2f1ab0b1821998bebbf11614b0959e948571`, branch `main`.
The working tree was clean at entry. This review changes documentation and adds diagnostic
reproductions only; **none of the application defects below has been fixed in this milestone**.

## Assessment

There is useful, working collection infrastructure, but code work is **not exhausted**.
Eight actionable findings were reproduced: **one P1, six P2, one P3**. Fix the persistence
failure first, then phone queue recovery, collection validation and restore verification.
These repairs need neither cattle labels nor a physical phone. Physical camera/plugin behavior
and animal-model accuracy remain separate verification gates.

P1 means a high-impact defect to fix next; P2 means a concrete correctness/reliability defect;
P3 means a low-frequency validation defect. Failure injection demonstrates behavior under the
specified condition; it is not evidence that existing farm data has already been damaged.

## What was checked

Reviewed backend routes, authentication, validation, image decode/QC/detection/storage,
registration and idempotency transactions, models and migrations, valuation and spoof signals;
Flutter capture/lifecycle/GPS code, API client, offline queue and local QC; research import,
preprocessing, artifact validation and matching metrics; backup/restore, configuration,
Docker setup and native Android signals. Generated platform boilerplate and third-party
dependency source were not exhaustively audited.

Fresh results on 2026-10-13:

| Check | Result |
|---|---|
| Backend/tooling pytest | 122 passed; one upstream TestClient deprecation warning |
| Research pytest | 45 passed |
| Ruff: backend, research, tools | Passed |
| Flutter analyze `--no-pub` | No issues |
| Flutter test `--no-pub` | 17 passed |
| Targeted audit probes | Findings below reproduced using synthetic data/fault injection |

Initial sandbox runs lacked temporary-directory/SDK access; the authorized reruns above
completed successfully. Those environment failures are not counted as application bugs.
The isolated `biolivestock-reliability` Docker containers were inspected and were stopped;
they were not started or modified. Docker/PostgreSQL upload/restore and APK build evidence
from October 8 remains historical, **not a fresh Docker or phone verification**.
No dependency vulnerability scan, real network-fault injection, load benchmark or iOS build
was performed. Passing existing tests does not cover the reproduced failure cases.

## Findings, in repair order

### F1 — P1: uncertain COMMIT outcome can delete an already committed image

**Location:** `backend/app/services/collection.py:124–130`; receipt replay in
`backend/app/services/idempotency.py:33–39`.

The exception handler unconditionally rolls back and unlinks every new image. A failed
COMMIT acknowledgement does not establish that the database rejected the transaction.
In the audit, the DBAPI commit completed and then raised an injected connection-style error:
the API returned **503**, the capture and receipt remained committed, and the image was
**deleted**. Retrying the same key returned **201** from the receipt while its image was
still missing. This turns a recoverable upload retry into missing evidence.

**Evidence:** `backend_probe.py`, `ambiguous_commit` output. Real SQLAlchemy/SQLite transaction
with a fault injected in `dialect.do_commit`; no real PostgreSQL connection was interrupted.
PostgreSQL also distinguishes unknown transaction/statement outcomes in its
[error catalogue](https://www.postgresql.org/docs/16/errcodes-appendix.html).

**Fix:** distinguish failures before COMMIT from failures after COMMIT has been attempted.
Preserve files when the result is unknown; use a fresh session and the existing request key
or generated capture UUID to determine the outcome when possible. Do not infer absence
from a failed lookup. Keep unresolved files for reconciliation rather than deleting them.
Add a file durability step before DB commit and a receipt/storage consistency check so a
missing image cannot be presented as a successful save. No breaking schema change is needed
for the first repair; do not rewrite immutable capture/receipt evidence.

**Acceptance:** test rollback before commit, successful commit with lost acknowledgement,
lookup unavailable, retry after restart and ordinary duplicate retries. A committed row must
keep its files; an unknown outcome must preserve evidence. Repeat the critical cases on an
isolated PostgreSQL stack, including concurrent retries.

### F2 — P2: a malformed queue entry can block all pending captures or receipt review

**Location:** `mobile/lib/offline_queue.dart:96–137,181–197`;
`mobile/lib/capture_screen.dart:202–219`.

Journal parsing checks the outer map but does not validate the complete metadata/quality
shape. Sorting casts `timestamp` outside the per-entry error handler. One valid entry plus
one entry with `timestamp: null` makes `pending()` throw a type error with **no recorded
per-entry issue**, so healthy entries cannot be recovered/synced through that call.
Separately, one `{broken` journal makes `receipts()` throw and hides every valid receipt.
Recovered quality fields also reach unchecked casts in the preview callback.

**Evidence:** `queue_probe.dart`: actual Dart filesystem/journal calls, no mocked queue.
The trigger is a corrupt or incompatible journal, not a normally generated current capture.

**Fix:** introduce a typed, versioned journal decoder shared by pending, receipt review and
preview. Validate timestamp, labels, species and quality before adding an entry; sort parsed
UTC values only. Isolate each entry/receipt error, return healthy records plus issues, and
retain damaged files. Apply the same receipt validation everywhere, including a nonempty ID.

**Acceptance:** null/missing/non-string timestamp, malformed JSON, corrupt quality and receipt,
mixed healthy/damaged records and different backend/operator. Healthy records must remain
visible and uploadable; no evidence is deleted or silently relabelled.

### F3 — P2: restored crops/research files are not checked against backup hashes

**Location:** `tools/collection_storage.py:199–209` and `reconcile():84–98`.

The bundle is hashed before copying. After copying, restore checks table counts, the capture
index and live-original hashes only. Crops have no historical DB hash, and research files
are excluded from reconciliation. Injecting corruption into a copied crop and `scans.csv`
still produced **“Verified isolated restore”**. The bundle manifest already contains hashes
for both files, but destination verification does not use them.

**Evidence:** `recovery_probe.py`: a valid synthetic bundle, real copy/checksum code and
injected destination corruption; Docker/query calls mocked. This is a verification gap,
not a claim that an earlier real restore was corrupt.

**Fix:** after copy, compare the destination inventory and **every `files/` manifest entry**
with its recorded SHA-256, including research labels, crops and retained orphan files.
Keep database reconciliation as an additional check. On mismatch retain the clone for
inspection, return failure and never print a verified-success message.

**Acceptance:** mutate, remove or add a restored original, crop and research file separately;
all must fail. A clean bundle must still pass the isolated Docker restore drill.

### F4 — P2: local exposure checks can approve frames the server necessarily rejects

**Location:** `mobile/lib/quality_control.dart:30–44`; compare
`backend/app/services/quality_control.py:15–18`.

Mobile builds the brightness histogram **after resizing**, which averages away clipped
pixels. The server uses original-resolution pixels. For the same 1280×960 synthetic JPEG,
mobile passed (blur **967.91**, mean **52.09**); server rejected `too_dark` because **75%**
of original pixels were dark, exceeding the configured 60%. Both sharpness checks passed.
During offline collection this can waste a visit: the operator receives a local pass and
only learns that the image is unusable after reconnecting.

This mismatch was already acknowledged in PROGRESS; the audit supplies a concrete JPEG
reproduction. It is an algorithm mismatch, not a request to recalibrate thresholds without data.

**Fix:** calculate mobile exposure/clipping from oriented original pixels and resize only
for Laplacian analysis, using the existing species config. Keep the server authoritative.

**Acceptance:** shared JPEG/PNG fixtures for dark/bright clipping, gradients, EXIF rotation,
portrait resolution and borderline blur. Allow small decoder/rounding differences; do not
claim byte-exact OpenCV/Dart equivalence.

### F5 — P2: dataset validation accepts truncated JPEG pixel data

**Location:** `research/biolivestock_research/dataset.py:55–58`.

Removing the last 100 bytes of a generated JPEG, recomputing its hash and validating its
manifest succeeded. Loading pixels subsequently failed with `image file is truncated`.
Thus CSV import/manifest validation can report success, but extraction later fails on the
same image. Hash integrity confirms the supplied bytes, not their decodability.

**Evidence:** `backend_probe.py`, `truncated_jpeg`. Pillow documents that
[`verify()` does not decode image data](https://pillow.readthedocs.io/en/stable/reference/Image.html#PIL.Image.Image.verify).

**Fix:** after the format/pixel limit checks, require a full decode using the same orientation
and RGB conversion assumptions as preprocessing. Reopen if retaining `verify()`. Attach the
sample ID/path to the error and keep truncated-image tolerance disabled.

**Acceptance:** truncated JPEG payload, damaged PNG, oversized dimensions and valid oriented
images. Import/validate must reject unusable files before model construction or extraction.

### F6 — P2: self-intersecting chest contours produce accepted, inflated estimates

**Location:** `backend/app/services/valuation.py:31–42`.

Distinct points and matrix rank do not establish a valid ordered contour. Four square
corners in perimeter order give **180 cm / 408.04 kg**; the same corners in crossing order
give **217.279 cm / 572.545 kg** and are accepted. The reported Schoorl weight increases
about **40.3%** solely because of invalid geometry. The unverified-accuracy disclaimer
does not make this input a valid chest circumference.

**Evidence:** `backend_probe.py`, `self_intersecting_contour`; entirely synthetic geometry.

**Fix:** validate a simple closed contour in a fitted chest cross-section plane, reject
self-intersections, overlapping/retraced edges and materially non-planar inputs with an
explicit geometric tolerance. Do not silently reorder points or substitute a convex hull;
that would invent a measurement. Preserve the tape-measure path and calibration disclaimer.

**Acceptance:** crossed square, repeated/overlapping segments, collinear, non-planar and
valid translated/rotated/scaled contours. Geometry tests do not establish animal accuracy.

### F7 — P2: mobile accepts animal IDs the API permanently rejects

**Location:** `mobile/lib/capture_screen.dart:516–521`; server rule in
`backend/app/schemas/capture.py:26–33`.

`CON`, `NUL`, `COM1` and other reserved names pass the phone regex but fail server validation.
The audited `CON` case passed the mobile expression and received **422** at the API. A
locally approved photo can therefore enter the immutable queue with an unuploadable ID;
batch sync pauses when it reaches that item. Existing suggested field IDs avoid this, but
the UI should enforce the actual accepted contract.

**Fix:** extract a mobile animal-ID validator that matches the server, including case-insensitive
reserved names, and validate before capture/enqueue. Keep existing invalid entries for review;
do not silently change their original labels or request key. An explicit reviewed replacement
workflow can be separate from this small validation repair.

**Acceptance:** shared reserved-name/case/length/character fixtures on both sides and a widget
test proving invalid labels cannot start capture.

### F8 — P3: timezone-aware but UTC-unrepresentable timestamps produce HTTP 500

**Location:** `backend/app/schemas/capture.py:21`;
`backend/app/services/idempotency.py:18` and other `astimezone(UTC)` callers.

`0001-01-01T00:00:00+14:00` passes `AwareDatetime`, then overflows during UTC conversion.
An authenticated synthetic upload returned **500**, rather than a structured 422. This
is an extreme input boundary, unlikely to originate from the normal phone clock.

**Fix:** validate safe UTC representability at the schema boundary, including GPS observation
and market observation times. Reject unsupported values through Pydantic validation; do
not add an arbitrary field-date restriction or broad exception swallowing.

**Acceptance:** both year boundaries, positive/negative offsets and ordinary timezone values;
invalid inputs return serializable 422 without writing files or database rows.

## Suggested improvements, separate from confirmed defects

- **Phone workflow tests:** the current 17 host tests cover helpers, not CaptureScreen state
  transitions. Inject camera/location/API/queue boundaries and test permission denial,
  background/resume, offline restart, partial sync and storage-full behavior without a phone.
  Keep a physical-device check before farm use; host doubles cannot validate native plugins.
- **Reproducible builds:** record/pin a tested backend dependency set and Docker base/runtime
  versions. Current broad ranges and unpinned torch/torchvision allow rebuild drift. This
  review found no specific dependency CVE and does not claim a vulnerability scan.
- **Collection scale:** benchmark a 1,800-frame queue and matching PostgreSQL fixture. Queue
  refresh scans retained journals/receipts and the UI eagerly creates pending tiles. Add
  pagination/indexing only from measurements. The previous-capture query should also be
  checked with `EXPLAIN`; no throughput regression is claimed without a benchmark.
- **Phone evidence export:** add an explicit original/journal/receipt export plus verified
  acknowledgement-aware retention workflow. Backend backup currently cannot protect photos
  still stored only inside the phone. Never silently purge unacknowledged originals.
- **Before broader deployment:** replace development HTTP/static binary-embedded keys with
  an appropriate transport/credential flow, separate release signing from debug keys and
  bound concurrent request buffering. These are known local-development limitations, not
  grounds to change the current trusted USB workflow during this audit.
- **Research hygiene:** consider decoded-pixel duplicate review alongside file hashes before
  evaluating real labels. The current check detects byte-identical files, not re-encodes or
  near-duplicate frames. Preserve independently established animal/session labels; no new
  embedding/model work is needed for any audit repair.

## Implementation sequence and completion gates

| Milestone | Work | Required proof before local commit |
|---|---|---|
| 1. Preserve upload evidence | F1; isolate pre-commit vs unknown-commit failure; durable file writes; reconcile/replay safety | Fault-injection tests plus isolated PostgreSQL retry/concurrency check; no committed image removed |
| 2. Recover healthy phone entries | F2 and F7; typed journal/receipt validation, per-item errors, matching animal-ID validation | Mixed healthy/corrupt queue tests and mocked-screen capture validation; files/labels retained |
| 3. Align field QC | F4; original-resolution exposure histogram in Dart | Shared server/mobile clipping fixtures, existing tests and Flutter analysis |
| 4. Verify complete recovery | F3; destination file inventory and hashes | Crop/research corruption tests and a new isolated Docker restore, preserving existing data |
| 5. Tighten research/API inputs | F5, F6 and F8 | Full decode, geometry and timestamp regression tests; normal valuation/import fixtures still pass |
| 6. Recheck and hand off | Run relevant suites; update docs and PROGRESS; phone checklist when available | Python/Flutter checks; no new animal accuracy claims; each milestone committed locally, no push |

No paid service, new account, sheep-specific logic, biometric model training or breaking
schema migration is required for these repairs. Scope for this turn was audit and plan;
the next implementation task should start at milestone 1, not wait for animal photos.
This original plan has since been completed in the linked repair follow-up.

## Reproduce the audit

The committed scripts under `docs/audits/2026-10-13/` are **diagnostic probes of current bugs**,
not regression tests whose broken behavior should be preserved. Convert them into tests
asserting the repaired behavior during implementation. They use generated bytes, disposable
SQLite and ignored `work/audit_20261013/` files. The restore probe mocks all Docker calls;
it cannot alter a real database. Run from the repository root, with existing dependencies:

```powershell
.\.venv\Scripts\python.exe docs/audits/2026-10-13/backend_probe.py
.\.venv\Scripts\python.exe docs/audits/2026-10-13/recovery_probe.py
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe docs/audits/2026-10-13/queue_probe.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=mobile/.dart_tool/package_config.json docs/audits/2026-10-13/quality_probe.dart
```

Run the backend probe before the quality probe; it generates the shared JPEG. The injected
COMMIT failure intentionally logs a persistence error. JSON output records the observations.
The queue probe exercises the queue directly; its reserved-ID check runs the exact current
validator expression, not a physical camera or widget. Baseline checks:

```powershell
.\.venv\Scripts\python.exe -m pytest -c backend/pyproject.toml backend/tests -q -p no:cacheprovider
.\.venv\Scripts\python.exe -m pytest -c research/pyproject.toml research/tests -q -p no:cacheprovider
.\.venv\Scripts\python.exe -m ruff check backend research tools --no-cache
Set-Location mobile
C:\src\flutter\bin\flutter.bat analyze --no-pub
C:\src\flutter\bin\flutter.bat test --no-pub
```

## Git and remaining empirical limits

Entry `git status --short` was empty. Entry HEAD:

```text
d99c2f1 Persist camera captures offline with restart-safe upload retries
```

Verified origin:

```text
origin  https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin  https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

The audit documentation/probes receive their own local commit after this revision. No push,
normal-stack deployment, data deletion or application-source edits are part of this audit.
Cattle muzzle checkpoint is still absent; `pending_model` is intentional. Sheep stays disabled.
Actual phone capture, labeled cattle matching accuracy, attack-video reliability and weight
calibration remain unverified and must not be inferred from these synthetic tests.
