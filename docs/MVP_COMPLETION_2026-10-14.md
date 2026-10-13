# Data-independent MVP completion audit

Reviewed the live roadmap, persistent progress and backend/mobile collection,
quality, detection, authentication, provenance, registry and recovery code. The
review found specific remaining registry/storage defects and workflow gaps; these
are repaired. This is completion of the defined MVP and existing groundwork,
not a claim that every future feature or real-world accuracy has been established.

| Finding | Completed change | Evidence |
| --- | --- | --- |
| Old animal/slaughter result remained after a failed lookup | Clear identity/report/history before each lookup; fail closed on wrong-ID responses. Add manual registry refresh. | Widget regression verifies old positive slaughter result disappears after offline lookup. |
| Version/owner/lifecycle were read separately; list used per-row queries | One joined statement snapshot for record/profile/terminal event; one query per list page/detail. Mobile reads the animal/report from one response. | API statement-count/coherence test; 200 real PostgreSQL HTTP reads during 30 owner changes, with actual overlap and no torn version/owner. |
| Separate mobile journal objects could issue simultaneous intents | Canonical phone-directory guard across journal instances; serialization includes submission, retry and acknowledgement. Safe key/link checks preserve evidence. | Two instances with alias paths cannot submit/retry concurrently; the next attempt recovers the existing ID. |
| Phone terminal form could not attach uploaded scan evidence | Optional uploaded capture UUID, validation, immutable retry, selectable recorded UUID/hash. | Widget checks invalid UUID/no request, normalized valid UUID and lost-reply replay; API rejects wrong animal/unauthorized capture without closing/version change. |
| History stopped at 50 records | Previous/next history pages, page indicator and retained page with explicit failed-read notice. | 51-event widget case reaches page two and recovers after failure. |
| Linked storage directories could redirect image writes | Reject symlinks/junctions and resolved escapes before creating files; recheck after directory creation. | Real Windows junction tests for outside storage and an alias within storage; no files created at destination. |

339 distinct tests passed: 198 backend/tooling, 48 research, 93 Flutter. Ruff and
Flutter analysis clean. The full Python run passed 246 cases; the only warning is
the existing upstream TestClient/httpx deprecation. No new dependency, schema,
model, sheep activation, cloud service or CI/CD was introduced.

Final Android debug APK built in 30.1 seconds, SHA-256
`f174e598090052164af0be2746b029b60b56be672fbc9c5f32c3f29cf5669b77`.
The preceding build took 34.7 seconds; the final build follows an analyzer-only
brace correction. No operator token configured; use README defines for runtime.
Host mock renders do not replace physical Android/iOS camera/GPS/share checks.

Runtime evidence is retained under ignored data/reliability/evidence:
registry-snapshot-20261014.json (200 reads/30 writes),
registry-completion-20261014.json (registry/QC/upload/attachment), and
registry-final-storage-20261014.json (final source/storage/upload check).
Backups/restores preserve originals, metadata, IDs/counters, owners and immutable
audit/receipts. No normal collection stack or real animal records were changed.

Final bundle data/backups/mvp-final-20261014 restored into new
biolivestock_restore_mvp_final_20261014 and data/restores/mvp-final-20261014.
Source/clone: 51 profiles, 58 animals, 114 audit events, 91 registry receipts,
12 captures/11 upload receipts and one counter; all registry/animal/audit contents
match, and file reconciliation is healthy. Earlier intermediate completion backup
and clone are retained too. Evidence mvp-final-restore-20261014.json. Both isolated API/database services stopped with exit 0; all volumes, fixtures and backups retained.

## Remaining gates

- A repaired/replacement phone: native permissions, preview/orientation, GPS,
  keyboard, real photo memory/storage, offline restart/upload, UUID attachment,
  history, registry acknowledgement and durable ZIP sharing.
- Independently reviewed real cattle identity/session images and a trained muzzle
  checkpoint: nose detection accuracy, QC calibration and held-out matching errors.
- Genuine/attack video labels: reliable liveness and presentation-attack decisions.
- Measured scale weights/calibrated geometry and actual market observations:
  estimation error and defensible valuation. Existing formula/price arithmetic is
  tested; real-world accuracy is unverified.
- Sheep data/models/calibration and a field pilot remain later and disabled.

Permanent MAA-series numbering, recorded owner/terminal history, authentication,
quality/cropping plumbing, duplicates review, formula/price groundwork, advisory
spoof/GPS signals, offline/retry/recovery and minimal admin endpoints are built.
They do not provide production biometric, legal ownership, independent slaughter
or liveness proof. No additional model work was started without data. Field
collection follows DATA_COLLECTION_GUIDE.md; backend/app rebuild follows README.
