# Chorvam — persistent project memory

Updated **2026-11-13, Asia/Tashkent**. Root: `D:\Coding projects\moliddetector`.
At every new session read this file and `docs/OFFLINE_FIELD_GUIDE.md`, inspect live
Git, and update this file before stopping/context exhaustion. Past contradictory
snapshots are preserved in `docs/history/PROGRESS_THROUGH_2026-11-12.md`.

## Exact current stop point

**All nine agreed backlog items are built and validated; item 9 publishing next.**
Latest published commit before final cleanup is **aa83963**. Full final checks
completed 2026-11-12: **210 Flutter tests, 253 backend/tool tests, analyzer and Ruff
clean**. Both prod/demo ARM64 release builds passed. On 2026-11-13 personally
rechecked live Git, completed logs, APK SHA-256 and every bundled YAML/catalog byte;
no source changes since those tests (only final documentation updates).
Final cleanup refreshed ROADMAP/ARCHITECTURE and STATUS_FOR_PITCH, archived dated
progress notes, and fixed receipt-backed mobile vet badge. Seven targeted health
tests cover four locales at 320×720 / 200%, mismatched receipt/role rejection and
unchanged original event bytes. No phone/adb, purchase, project relicensing,
normal/live stack modification, real data deletion or ID change. Finish audited
fast-forward publication and clean Git verification, then stop feature work.

## Completed backlog

| Item | Published commit | Built / verification boundary |
|---|---|---|
| 1 Health | d422ea2 | Four offline event types/correcting records, CSV, idempotent MAA sync, immutable SQL history; synthetic tests and dedicated PostgreSQL proof. |
| 2 Ownership | a20a9f2 | Offline owner ID/name/date/optional whole UZS price/notes, predecessor chain, frozen expected_version sync; no legal title/payment claim. |
| 3 Slaughter QR | 5ad683e | Random revocable capability, private mobile share, strict public projection/rate limit; synthetic QR decode/privacy/revoke and SQL immutability proof. |
| 4 Partner panel | bc80f8b | UZ/RU SSR search/profile/photos/audit/finance, immutable explicit field-summary sync; synthetic PostgreSQL/API tests. Browser visual/JS unverified. |
| 5 Access roles | 727d3b3 | Five roles, Argon2id CLI/password login, session revocation, Secure cookies/CSRF/shared limits and RBAC; real isolated CLI/DB proof. |
| 6 Deploy kit | 7bfc55c | HTTPS Caddy/private DB+API/file secrets, rotated redacted logs, guarded backup/clone verification, monitor/systemd templates/UZ runbook. Actual local TLS/restore/monitor proof; no VPS/systemd/public-domain deployment. |
| 7 First-run guide | 3b01d78 | Four original-vector pages, four locales, durable UI preference and Tools replay; analyzer + 202 Flutter tests, release/package/signer/bundles verified. |
| 8 Separate demo | aa83963 | prod/.demo flavors, distinct OS sandbox and demo_capture_queue, six original NAMUNA JPEGs/read-only profiles, all-route banner, native mode fail-closed, no INTERNET permission plus Dart HTTP denial; analyzer + 209 Flutter tests/Ruff and both releases verified. |
| 9 Final cleanup | publishing | Truthful roadmap/architecture/pitch status, concise persistent memory with preserved history, scoped receipt-backed mobile vet badge. Full analyzer/210 Flutter/253 backend/Ruff and both release APKs verified. |

Final completed backend/tool suite: **253 passed**, canonical Ruff clean.
Final item 9 Flutter suite: **210 passed**, analyzer clean (item 8 had 209).
Synthetic widget tests are not physical Android camera/AR/biometric field results.

## Direct evidence and isolated stacks

- Backlog Docker: `chorvam-backlog-20261111`, `backend/docker-compose.verify.yml`,
  loopback **18001**, private `data/verification-backlog-20261111` bind/credentials.
  `tools/verify_backlog_docker.py --stage health|ownership|qr|panel|roles` guards
  bindings before mutating. No normal stack touched.
- Real panel proof: `data/verification-backlog-20261111/evidence-panel-458fddd9ee5f4edfa8e2c0d333e56d1a.json`.
  Roles: `.../evidence-roles-ff81b44f236e4f7e9d8cf68ff6e65784.json`.
- Production test: `chorvam-prodverify-20261112`, loopback HTTPS **18443** / HTTP
  **18480**, separate DB/Caddy volumes and `data/verification-prod-20261112`.
  Actual CA+hostname-verified TLS, automatic Secure-cookie jar login, CSRF deny /
  authorized vet write, private photo, real synthetic JPEG QC/upload/replay/SHA /
  PostgreSQL `pending_model`, public QR privacy and log redaction passed:
  `data/verification-prod-20261112/evidence-https-6f96d87da3a9421dbeeed4ac1631397e.json`.
  No verify=False, forced cookie header or global Windows trust changes. This is
  HTTP client transport proof, not browser visual/JS or device verification.
- Backup `20261112T065444Z-5a866c04` restored into fresh
  `biolivestock_restore_be3e9ee9050340598bc1` and a new clone folder; schema,
  counters, table counts and all file hashes matched. Receipt:
  `data/verification-prod-20261112/backups/20261112T065444Z-5a866c04-verified.json`.
  API restarted; no clone promoted, counters reset or evidence purged.
- Monitor HTTPS/disk/backup age healthy: `data/dev/prod-monitor-verification.log`.
  Local proof used explicit 1 GiB minimum (D: had ~3.6 GiB free), production
  default remains **10 GiB**. Do not delete retained data/artifacts/backups to
  make space without authorization.
- Historical report: Sardorbek visually confirmed both Docker Desktop containers
  healthy and repeated health 200 responses. New isolated checks above were
  personally executed; neither implies tests on the ordinary stack/real cattle.

## Key Decisions & Config — do not re-litigate

- Current user task explicitly forbids adb/install/device testing. Earlier phone
  repair/connected-phone reports in history are historical, not current commands.
- Ordinary origin main fast-forward push is authorized after each milestone and
  publication audit. No force/rebase/history rewrite. Unexpected remote commits
  or an actual secret discovery => stop publication and report. Data/artifacts,
  credentials, model weights, real images and backup/restore files stay ignored.
- Muzzle checkpoint absent: **pending_model**, no COCO cow substitute, no fake
  crop/detection/automatic identity/weight/liveness. Human-confirmed ORB is advisory.
- Cattle active, sheep config/enum present **disabled**; no sheep model/crop code.
  Species/business/security YAML is authoritative and bundled/hash-checked.
- Canonical MAA counters never reset/reuse; local random L IDs are provisional.
  L→MAA mapping/operator/intents and original scan JSON stay immutable. Authorize
  before receipt replay; client assertions/GPS are not server attestations.
- Health is append-only: name alone is not vet confirmation. Server veterinarian
  role alone gives badge; mobile uses matching immutable scope/body/role receipt.
  Mobile does not fetch every remote vet event; private panel reads server history.
- Five roles: admin/operator/veterinar/bank_viewer/bank_officer. Partner panel reads
  one agreed pilot registry, not bank-isolated tenants. Status != loan/policy/title.
  Public QR exposes only ID/slaughter date/facility/latest verified vet date;
  registry record, not laboratory food safety or physical slaughter proof.
- `mobile/android/gradle.properties`: **kotlin.incremental=false** remains required
  for D: project vs C: Pub/Gradle roots. Keep until a separately verified toolchain
  change resolves it; do not move/reset user caches to diagnose again.
- AR frozen same-frame raw depth/confidence/pose/intrinsics, no inter-frame point
  segments. Two sides / optional front, fast/contour kept; 5% repeats, learned
  ratio min 3 distinct animals and scale correction min 10 are config values.
  Mode/width-source/config cohorts and raw/corrected estimates never mix.
  ar_policy_version 3 excludes unrelated config sections from AR correction keys.
- Native prod package **ai.biolivestock.biolivestock_capture**, versionCode **1**,
  original debug signer SHA256 **8e43cfb55a120f18a62cf955d19a5ed40816f34a96c1416b27644b08de500c90**.
  Demo suffix .demo, no network/camera/AR actions. Sample dates/IDs/photos are not
  animal evidence; original vector/JPEG artwork, no third-party animal photos.
- HTTPS uses pinned Caddy 2.11.9 Apache-2.0; new backlog libraries are permissive.
  **Existing Ultralytics is AGPL/Enterprise, not permissive** (upstream in NOTICE).
  No paid license or project relicensing; commercial detector licensing/product
  choice remains external. Do not claim the entire backend is GPL/AGPL-free.
- Official ARCore sample code Apache-2.0 is distinct from SDK binary terms. NOTICE
  retains sources/licenses; renderer original, no unlicensed GitHub code copied.
- File-mounted DATABASE_URL_FILE must be read by API, Alembic and independent CLI.
  Preserve exact existing offline operator ID when making first pilot credentials;
  user CLI identities must not collide with bearer actors. Never print raw secrets.

## Artifacts and commands

Latest verified final APKs (built 2026-11-12, rechecked 2026-11-13, ignored):
- `data/artifacts/chorvam-final-prod-20261112/app-prod-release.apk`
  SHA256 `ca96fef8d1b49f84eb3400fa997f3b8707f059d06e188e8847d2afd60d8a78e6`.
- `data/artifacts/chorvam-final-demo-20261112/app-demo-release.apk`
  SHA256 `1d81cea1703dc48f95684bea472843992bedf90f168324345ea92490bcd6ed49`.
No phone installation. Original signer/version and opposite network permissions
verified. All four YAML bundles and four locale catalogs byte-match source in
both actual APKs. Logs: `data/dev/chorvam-final-20261112-{analyze,flutter,pytest,ruff,prod-release,demo-release}.log`.
Build times: prod 2m49s, demo 2m09s. Existing dependency/Gradle deprecation warnings
are not failed checks; do not upgrade the toolchain as an unrelated final task.

Flutter `C:/src/flutter/bin/flutter.bat`, Python root `.venv/Scripts/python.exe`,
Java Android Studio `jbr`. Full Flutter tests use --no-pub --concurrency=4.
**Run Ruff from backend**: `../.venv/Scripts/python.exe -m ruff check . ../tools ../research --no-cache`.
Root --config changes import classification; do not mass-reorder unrelated files.
Backend pytest from backend: `../.venv/Scripts/python.exe -m pytest -q -p no:cacheprovider`.
Build/archive both flavors using `tools/build_mobile_release.ps1`, unique
-Milestone folders; package/version/signer/network permissions checked, no adb.

## Remaining gates and next real action

Finish item 9 audited push / clean Git proof, then stop coding. All agreed code,
synthetic tests and release artifacts are complete. No new feature is pending.
Real animal sessions/ground-truth identities, TP/FP/FN/latency counts, labeled
muzzle model data and independent scale measurements are externally missing.
Founder reported two cattle properly tried on **2026-11-06**, movement/blur,
no counted attempts or accuracy. Six-November is a date, not six successes.
Latest-APK physical runtime/AR suitability remains unverified. Collect by
DATA_COLLECTION_GUIDE/OFFLINE_FIELD_GUIDE; do not invent accuracy or photo weight.
Public server/domain/offsite destination and partner access/legal permissions
require Sardorbek; no purchase/account. Existing Ultralytics licensing choice
must be resolved before commercial detector rollout. No routine code decision
needs his input now; these are the genuine outstanding external decisions.

## Git evidence — after item 8 push, before item 9 changes

```text
aa83963 Isolate synthetic presentation demo with native flavor and network denial
3b01d78 Add persistent four-language first-run field guide and replay
7bfc55c Prepare isolated HTTPS pilot deployment and verified backup tooling

origin	https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (push)

git rev-list --left-right --count HEAD...origin/main
0 0
```
Working tree has item 9 changes; not claimed clean at this checkpoint.
