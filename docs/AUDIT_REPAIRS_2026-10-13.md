# Verified audit repairs — 2026-10-13

All eight confirmed findings in [the audit](CODE_AUDIT_2026-10-13.md) are implemented.
These repairs preserve the species-config pattern, disabled sheep, append-only evidence and
`pending_model` collection. No database migration, external service or real animal data was needed.

| Finding | Implemented behavior | Regression evidence |
|---|---|---|
| F1 | Flush SQL before COMMIT; retain files after any attempted/uncertain COMMIT; file fsync before commit and directory fsync on Linux; replay checks retained original hash and crop existence | SQLite commit-then-lost-ack test; real PostgreSQL driver fault after commit; concurrent authenticated HTTP retries |
| F2 | Shared typed version-1 journal and receipt decoder; per-file issues; healthy entries/receipts remain accessible; typed preview values and UTC ordering; read-only nested metadata | Mixed valid/corrupt metadata, quality, JSON and receipt tests; original labels/files retained |
| F3 | Hash-check every restored `files/` entry and inventory, including research labels/crops, before verified success | Nine changed/missing/extra restore-copy cases; complete Docker backup/clone restore with synthetic research files |
| F4 | Original-resolution exposure histogram in Dart; resize only for blur; existing thresholds preserved | Same dark/bright JPEG/PNG fixtures rejected by both Python and Dart |
| F5 | Full oriented RGB pixel decode after structure/size/hash validation | Truncated JPEG rejected before extraction; existing import/manifest tests pass |
| F6 | Ordered chest contour must be simple and planar; crossings/overlaps/backtracking rejected; no automatic reordering or hull substitution | Invalid contours rejected; valid translation/rotation/scale and formula arithmetic preserved |
| F7 | Shared mobile animal-ID validator matches backend reserved-name policy before capture/enqueue | All reserved names/case variants; invalid form cannot submit |
| F8 | SafeTimestamp checks UTC representability for capture, GPS observation and market observation | Both extreme date boundaries return validation errors; upload returns 422 with no files |

Geometry tolerances live in both business configs, with defaults for existing configs:
1% planarity error relative to contour extent and 1e-6 numerical geometry epsilon.
These are engineering validity rules, not measured animal-accuracy thresholds. Evidence
snapshots retain complete configs. Cattle weight formulas and yields are unchanged.

## Fresh verification

- **151 backend/tooling tests + 46 research tests + 53 Flutter host tests passed (250 total).**
- Ruff passed on backend/research/tools; Flutter analysis had no issues.
- Android debug APK built successfully; SHA-256
  `4f339a1cdcaaba5fb735a2c8cb5880aabbb3438557f84b0d27413556cc38045c`.
  It contains no configured API token. Use the README's operator-configured build/run command.
- Real isolated Docker/PostgreSQL stack `biolivestock-reliability`, port 18001, returned healthy.
  All **47** backend/migration/config source hashes matched the container.
- Actual DBAPI fault after a real PostgreSQL COMMIT preserved the original and same-key replay:
  capture `2cffb976-5575-44b2-969b-502c4c6ccb1f`; evidence
  `data/reliability/evidence/commit-recovery-20261013.json`.
- Four concurrent authenticated HTTP retries created one capture/receipt; changed payload 409,
  bad credential 401 and wrong authenticated operator 403. Evidence:
  `data/reliability/evidence/idempotency-20261013.json`.
- Dart QC/filesystem/HTTP test simulated response loss after persistence, reopened the queue
  and returned the same UUID `3b4ae812-b25c-4538-89a7-0d2a554efeec`, preserving local originals.
  Journal/receipt evidence: `data/reliability/mobile-queue-20261013`.
- Backup `data/backups/reliability-repairs-20261013` verified and restored into the new
  `biolivestock_restore_repairs_20261013` database and
  `data/restores/reliability-repairs-20261013` directory. Original hashes, every copied file,
  table counts and capture index agreed, including clearly marked synthetic research labels
  and JPEG fixture. Read-only reconciliation was healthy:
  `data/reliability/evidence/reconcile-repairs-20261013.json`.

The first Docker rebuild captured intermediate source before the new geometry config was
mounted; startup correctly rejected the unknown fields. Rebuilding the completed source
resolved that mismatch. The final runtime verification used the matching completed image.
This was isolated test setup; normal collection stack/data were not changed.

The PostgreSQL proof injects a driver error **after actual commit**; it does not claim an
actual network outage. The Dart integration and APK build do not establish physical camera,
permission, GPS or lifecycle behavior on a phone. Real cattle inference/matching, liveness
and weight accuracy still require data and field calibration. No sheep model work was added.

## Operational consequences

Retry an uncertain upload with its original key, bytes and metadata. An uncertain COMMIT
can leave an orphan if it really rolled back; preserve it for reconciliation. A receipt with
missing/changed evidence now returns 503, rather than claiming a successful save. Restore
the retained evidence through a reviewed recovery process; never change immutable DB records
or silently relabel a queued capture. Corrupt phone entries remain on disk with issues.

After review, rebuild the normal backend with `docker compose up -d --build` from backend/,
and rebuild/run the app with the README's operator token and URL. Preserve the phone's
existing application data. Physical-device pre-trip verification remains required.

Local milestones: `d3704e5` (F1), `4ac39d8` (F3), `8c722c2` (F5/F6/F8),
`de5e76d` (F2/F7), `0ba8dd7` (F4), followed by this verification/documentation milestone.
No push, normal-stack deployment, existing data deletion or breaking schema change.
The audit's optional enhancements remain a backlog, not unresolved confirmed defects.

## Repeat the relevant checks

Existing test commands are in [VALIDATION.md](VALIDATION.md). The new PostgreSQL fault
probe intentionally writes one synthetic capture and accepts only the isolated test project:

```powershell
.\.venv\Scripts\python.exe tools/verify_commit_recovery_docker.py --output data/reliability/evidence/commit-recovery-NEW.json
.\.venv\Scripts\python.exe tools/verify_idempotency_docker.py --output data/reliability/evidence/idempotency-NEW.json
```

Use new evidence paths; do not overwrite earlier results. Backup/restore commands and
maintenance requirements are in [COLLECTION_RELIABILITY.md](COLLECTION_RELIABILITY.md).
The original audit probes preserve the earlier failure reproductions; they are historical
diagnostics and can stop early now that bad input is correctly rejected. The regression
tests are the acceptance checks for current code.
