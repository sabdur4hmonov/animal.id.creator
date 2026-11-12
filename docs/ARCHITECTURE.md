# Chorvam architecture — 2026-11-12

## Boundaries and species configuration

Flutter native camera → local QC → immutable phone evidence → explicit idempotent
FastAPI requests → authoritative server QC → optional muzzle detection/crop →
filesystem originals + PostgreSQL metadata. No gallery picker or implicit model
download. `species_configs/<species>.yaml` controls enabled state, trained model
path/class, framing/crop/resolution/QC; `business_configs/` controls formulas,
AR/repeat/calibration, prices, ownership and experimental advisory matching;
`security_configs/` controls review heuristics. Backend validators and hash-checked
bundled mobile YAML share these definitions. Cattle is active; sheep's same-shape
configs/enum remain disabled. Future sheep needs real data, validated values and
model assets, not a new detector/storage endpoint or species-specific crop branch.
The current collection UI deliberately targets cattle. Goats are not implemented.

`backend/app/models/` is SQLAlchemy, while ignored `models/<species>/` is binary
weights. YOLO filters exactly one configured muzzle class, checks/pads/clips the
box and QC-checks the crop. COCO cow boxes are not nose models. No trained muzzle
checkpoint exists: accepted original is `pending_model`, not a confirmed muzzle
or animal identity. A present broken model is unavailable rather than silently
accepted. Existing pending originals are not silently reprocessed.

Server EXIF orientation/normalization, decoded-pixel/encoded-byte limits,
Laplacian variance and full-image lighting histogram remain authoritative; mobile
QC is advisory and bounded. QC score is not a calibrated identity probability.
GPS can be null; timestamps are timezone-aware UTC. Immutable configuration,
operator/capture assertions, server receipt time and file SHA remain separate.
Stored images use species/animal_id/UTC-date/unique-capture names. File fsync
precedes database commit; uncertain commits preserve evidence for reconciliation.

## Offline identity, capture and geometry

`FieldStore` keeps append-only per-animal/photo/measurement/price JSON and original
JPEGs; compact profile indexes/thumbnails do not load raw depth into lists. A local
random L-label is provisional. Only the canonical PostgreSQL atomic allocator
issues MAA-series IDs (AA..ZZ blocks of 99,999,999); counters never reset/reuse.
Mapping freezes original operator/owner/request intent before HTTP. Retries reuse
the same key/receipt; historical L metadata is retained. Death/slaughter archive
records retain IDs/photos, never delete animals to make numbers available again.

Android OpenCV ORB/ratio-test/RANSAC produces experimental top candidates, followed
by explicit human confirmation. No automatic merge, identity selection or invented
accuracy. Decisions/config/hash/time go into the append-only evaluation ledger.
Four-second burst saves selected original JPEGs, not MP4, and each frame needs its
own animal confirmation. Whole-body left/right photos and dated actual scale
observations support future data collection, without photo-derived weight.

AR snapshot unprojects tapped pixels from each frozen frame's own depth/confidence,
intrinsics and pose. Left/right segments never join points across frames; repeat
rules gate the combined estimate. Optional front width is measured within its own
frame; otherwise a versioned median ratio needs at least three distinct
species/breed fast-mode animals. Fast six-point ellipse and closed 3D contour
remain separate modes. Original points, segment lengths, tracking, JPEG/depth and
provenance are retained; repeat 5% and minimum-ten-animal scale correction are
configuration values. Width source/mode/config revisions keep correction groups
apart; both formula results and raw/corrected estimates stay visible. Real accuracy
and supported-device behavior still require field testing. Official ARCore SDK
and original renderer: see NOTICE for sample-code versus binary terms.

## Pilot records, access and public boundary

Additive Alembic migrations preserve capture schema and old receipts. Health events
and correcting events, ownership/sale history, field summaries, QR issuance/revocation
and audit/receipts are append-only (database guards included). Current animal,
financial status, user/session/rate state are mutable projections with optimistic
version checks where applicable. Sale price is optional whole UZS, not a payment.
Compact field summaries sync only explicit tag/valid measurement/scale records;
raw depth remains local/ZIP. Health and ownership have their own frozen retry flows.

Bearer credentials remain supported. Five authoritative roles are admin, operator,
veterinar, bank_viewer, bank_officer. Operator management is scoped to its records;
partner roles read the agreed pilot registry, not separate bank tenants. Only the
veterinar actor role creates a verified health badge. Mobile derives it only
from a matching frozen intent/server receipt, not the entered veterinarian name;
it does not pull the entire remote health history back to the phone. Finance changes require
admin/bank_officer, reason and expected_version. Authorization precedes receipt
replay, so downgrade cannot replay old writes. Argon2id password accounts created
by CLI use revocable opaque SHA-hashed sessions, Secure/HttpOnly/SameSite cookies,
CSRF and shared database login limits; credentials and role are rechecked.

UZ/RU server-rendered `/panel` lists/searches profiles and audit, renders protected
photos, and guards finance changes. Public slaughter URLs use random revocable
capabilities with rate limits and no-store/no-referrer policy. Their strict public
projection contains ID, slaughter date, facility and latest unsuperseded verified
vet examination only—never owner/GPS/price. This is a registry report, not physical
slaughter verification, laboratory testing or legal title/credit approval.

## Deployment, demo and verification

Normal development Compose is retained. `backend/docker-compose.prod.yml` adds
pinned Caddy HTTPS, private DB/API, file secrets, read-only/non-root API, a narrowly
trusted proxy and bounded rotated logs with QR/credential redaction. Explicit
PUBLIC_ORIGIN is required; API, Alembic and independent user CLI read the same
DATABASE_URL_FILE. Backup tooling quiesces only its selected API, retains immutable
bundles, checks schema/counts/ID high-water marks/files in a new restore database
and folder, and records external verified receipts. Monitor checks HTTPS, free
space and restore-proof age. Timer templates are prepared; no VPS/domain, systemd
installation, off-site service, cloud deployment or CI/CD is claimed.

A dedicated local project proved real TLS with a client-only trusted test CA,
Secure-cookie login/CSRF, QC/JPEG/PostgreSQL pending_model upload/replay, public QR
privacy/log redaction, clone restore and monitoring. Normal stacks/real IDs were
untouched. Browser visual/JS, latest-APK device behavior and farm accuracy remain
unverified; automated tests use synthetic records/images. Evidence paths/counts
and artifact hashes live in PROGRESS.md, ignored raw evidence under data/.

First-run guide completion is a UI preference outside immutable journals. Android
prod flavor preserves package/version/signer; .demo has its own OS sandbox and
demo_capture_queue, six original NAMUNA drawings, read-only profiles and persistent
above-Navigator disclosure. Installed native package chooses mode before workflows;
unknown mode fails closed. Demo has no INTERNET permission and API calls are also
blocked in Dart. It cannot capture, measure or send synthetic records. It is a
presentation aid, not evidence of recognition/weight accuracy.

Research-only embeddings/evaluation remain in `research/`, with separate model
configs and no production vector DB/identity endpoint. Heuristic anti-spoof signals
stay review-only/not_assessed; real labeled cattle/attack data, scale calibration,
phone checks and partner/server decisions are the remaining validation gates.
See ROADMAP.md, STATUS_FOR_PITCH.md, ACCESS_ROLES.md and DEPLOY_RUNBOOK.md.

Existing dependency boundary: backend/requirements.txt retains Ultralytics from
the original detector stack. Its upstream offers AGPL/Enterprise options
(https://www.ultralytics.com/license); the whole backend is not GPL/AGPL-free.
No new copyleft dependency, paid license or project relicensing was introduced.
Resolving commercial detector licensing is an external product/legal decision.
