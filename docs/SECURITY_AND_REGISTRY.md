# Local authentication and registration controls

## Safe upload retries

Send `Idempotency-Key` (16–128 ASCII letters/digits/underscores/hyphens) on `POST /api/v1/captures`.
Generate it once per capture and retain the exact image bytes and capture metadata for retries.
Keys are scoped to the authenticated operator ID, including across key rotation. The same key/payload
returns the original HTTP 201 response/UUID without new images, scans or duplicate-review events.
Different image bytes or metadata with a committed key return 409; authentication and operator binding
still apply. Failed validation/QC/persistence does not consume a key. Requests without a key keep the
old behavior, creating a new scan. Do not invent a new key merely because an upload timed out.

Additive migration 0004 stores append-only upload receipts in the same transaction as the capture.
PostgreSQL transaction locks serialize concurrent retries across API workers; a unique operator/key
constraint is the final guard. SQLite is used for sequential API tests, not the production concurrency
guarantee. Receipts have no expiry in this local collection MVP. Future removal requires a deliberate
retention policy because old retries would otherwise create new scans.

## Local keys and registry

Run `.\.venv\Scripts\python.exe tools/init_local_credentials.py` from the repository root once. It creates distinct random operator/admin bearer keys and SHA-256-only server records in ignored `backend/.secrets/`. No key is printed or included in the Docker build context. Start/restart Compose to load `api_keys.json`; absent credentials return 503 on protected endpoints, never anonymous access. `/health` stays public for container health checks. API schemas/docs are public, while `/api/v1/*` requires a key. Rotate by creating a fresh random token, replacing its server hash and client token, and restarting the API. Never use an admin key in the capture app.

Use `backend/.secrets/tokens.json` locally to retrieve credentials. Protect this file with your machine's user permissions; it is not a secrets vault. Development bearer keys identify operators, not hardware or organizations. There is no multitenancy/ownership/legal verification or external identity provider yet. Send keys over HTTPS before exposing the service outside a trusted local development network. A compile-time mobile API_TOKEN can be recovered from the app binary; this is a development client, not a production credential-distribution solution.

Mobile now needs `--dart-define=API_TOKEN=<operator-token> --dart-define=OPERATOR_ID=<authenticated-operator-id>` in addition to its API_BASE_URL. The upload's operator ID must equal the key's principal (403 otherwise). The server stores submitted GPS/capture time unchanged, plus its own UTC receipt time and hashes of submitted bytes, oriented pixels and stored JPEG. GPS/time from a client are claims, even when immutable; absent GPS is recorded null. Historical captures retain null new provenance fields rather than invented receipt times or image hashes.

`animals` has a `(species, animal_id)` registration key, status `open`, `insured`, or `collateral` (display labels Open / Insured / Under Loan or Collateral), and a version. A registration attempt for an existing key returns 409. Capture labels register automatically on first scan; existing captures are backfilled as open when the additive migration runs. Status is an administrator's recorded assertion, not evidence of a real insurance contract, loan, lien or government registration. Status/review edits require the current expected_version and a reason/note; stale requests return 409 and successful edits append audit events.

Exact oriented-pixel reuse generates pending duplicate cases, including repeated frames under the same label. PostgreSQL transaction-level fingerprint locks prevent simultaneous scans from missing exact reuse. At most 100 matches are materialized per scan; truncation is explicit. Distinct photos of the same animal and recompressed/altered replays are not resolved here. No biometric identity/duplicate model is used. Captures are retained for review. Administrators can flag a capture, confirm/dismiss/reopen a case, and inspect audit events; confirming never merges identities or deletes images.

PostgreSQL and SQLite migration triggers reject UPDATE/DELETE on captures and audit events; the ORM also rejects capture edits. Files remain local: stored SHA-256 detects changed bytes, but administrators with database/filesystem privileges can bypass protections. There is no hardware attestation, cryptographic location proof or external notarization. No scan-update/delete endpoint exists. The migration adds tables/nullable fields without dropping existing data; legacy hashes remain unknown.

Use Swagger `/docs` → Authorize for the minimum admin interface:

- POST/GET `/api/v1/animals`, GET `/api/v1/animals/{species}/{animal_id}`.
- PATCH `/api/v1/animals/{species}/{animal_id}/status` (admin).
- GET `/api/v1/captures/{uuid}` (own operator captures or admin).
- GET `/api/v1/admin/captures/{uuid}/integrity` (admin): matched, mismatch, missing, unsafe_path or unavailable_legacy; it inspects bytes without editing evidence.
- GET/POST `/api/v1/admin/duplicates`, PATCH `/api/v1/admin/duplicates/{uuid}` (admin).
- GET `/api/v1/admin/audit?species=cattle` (admin).

List endpoints require species, bound limit to 200, and accept offset. Sheep mutations remain disabled. Request bytes are bounded before multipart parsing, image limits remain enforced, and validation errors omit raw inputs so secrets/non-finite values are not echoed.
