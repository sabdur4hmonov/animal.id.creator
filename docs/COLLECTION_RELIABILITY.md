# Reliable collection, backup and recovery

## Phone collection

Connect once with the correct backend URL, operator ID and token to cache enabled species/QC settings.
Rebuild the backend first so migration 0004 is applied. The app checks the health capability before
uploading and refuses to send queued photos to an older backend without retry protection.
Then capture works without a backend connection. Before **Saved on this phone** appears, a local-QC
passing photo is copied into application-support storage with its metadata and random request key.
Failed local QC stays a temporary preview; retake it. **Next capture (saved locally)** retains queued
originals. App restart recovers them. Originals and receipts stay after upload; credentials are not
written to the queue. No background upload or automatic deletion is implemented.

Reconnect and tap **Upload pending captures**, or open one pending item and upload it individually.
Retries preserve image bytes, labels, GPS and capture time and send the same `Idempotency-Key`.
Server QC is authoritative: offline local passes are provisional. Batch upload pauses at the first error;
other items can be uploaded individually. Fix 401/403 credentials, 503 connection/service issues or
review 409/413/422 conflicts/validation failures. Do not edit queued labels or invent a fresh key to
bypass conflicts; recapture unsuitable images. Other-backend/operator entries and corrupt/missing
files remain visible as issues and are retained for review.

Record the request key for each offline shot. **Review saved upload receipts** shows its server UUID
and path after upload; copy those to the ledger. Interrupted acknowledgement safely replays the same
server receipt. Do not uninstall/clear storage while the phone holds the only copy. Check free space;
retained originals accumulate. Before a farm visit, prove: connected capture → disconnect backend →
capture/next → force-close/reopen → recover pending labels/image → reconnect/upload → check server
UUID/file. Host tests and an APK build do not establish physical camera/plugin behavior.

## Backup — repository PowerShell terminal

Use the project name shown by `docker compose ls` (normally `backend` for README setup) and its actual
host storage root. These examples use the normal `data/` mount. Database container must be running.
Use a new output path every time; files are not overwritten.

```powershell
.\.venv\Scripts\python.exe tools/collection_storage.py reconcile --project backend --storage-root data --output data/reports/reconcile-20261008.json
.\.venv\Scripts\python.exe tools/collection_storage.py backup --project backend --storage-root data --output data/backups/farm-20261008
.\.venv\Scripts\python.exe tools/collection_storage.py verify --bundle data/backups/farm-20261008
```

Reconciliation is read-only: missing, changed, unsafe and unreferenced files are reported, never deleted.
Exit 2 means inconsistency. Legacy originals/crops without historical hashes are explicitly listed as
`hash_unavailable`, not claimed integrity matches.

Backup briefly stops this project's API if running and restarts it in `finally`, including on failure.
Do not upload or directly modify files/database during this maintenance window. The tool checks the
actual API container bind mount and rejects a wrong project/storage pair. The bundle contains a
custom-format PostgreSQL dump (all tables), capture index,
cattle/sheep storage, research labels/crops/references and species/business/security configs.
Secrets and other backup/test/evidence trees are excluded. Keep credentials separately protected and
retain any required model checkpoints separately. Every included file has a checked SHA-256; originals
also match database hashes. Failure leaves an incomplete directory for inspection; only a
successful verified bundle is a backup. Copy the **entire directory** to a second drive. Protect backups
as animal/operator/location data. Hashes detect corruption, not authenticity.

## Restore drill — new clone only

Use trusted backups: dumps contain executable schema definitions. Restore requires an unused database
name with `biolivestock_restore_` prefix and an absent storage directory outside the bundle.

```powershell
.\.venv\Scripts\python.exe tools/collection_storage.py restore --project backend --bundle data/backups/farm-20261008 --target-database biolivestock_restore_farm_20261008 --target-storage data/restores/farm-20261008
```

The drill checks file hashes, all table counts and capture-index equality. It retains the clone on
success/failure; it never switches live connection/mounts, overwrites existing storage or deletes data.
Recovery cutover is a separate reviewed action. Keep the backup after a successful drill. Requirements:
Python 3.12+, Docker Compose and the existing PostgreSQL 16 container; no host PostgreSQL/cloud account.

References: [application-support paths](https://pub.dev/packages/path_provider),
[PostgreSQL custom dumps](https://www.postgresql.org/docs/16/app-pgdump.html),
[PostgreSQL restore](https://www.postgresql.org/docs/16/app-pgrestore.html).
