# BioLivestock AI — project progress

Last live repository inspection: 2026-11-11, Asia/Tashkent. Project root: D:\Coding projects\moliddetector. Read this file and inspect the live repository at the start of the next session. Distinguish direct checks, synthetic tests and Sardorbek's reports.

## Current stop point

**Item 4 complete — 2026-11-11, publishing.** Analyzer clean, **195 Flutter
tests**, **236 backend/tool tests**, Ruff clean. Directly verified private SSR
UZ/RU search by ID/tag, profile photos with stored-hash verification, ownership/
health/weight/slaughter/status display, paged audit, escaped hostile tags,
admin-only expected_version/reason finance edits and stale-version rejection.
Operator portal scope is own registered records; role-specific partner access
follows item 5. HTTPS TestClient verifies Secure/HttpOnly/SameSite=strict opaque
cookies, CSRF rejection, logout, expiry and credential invalidation. Actual
Docker/PostgreSQL summary/search/replay evidence is linked below. Phone runtime
and actual browser HTTPS remain unverified (item 6 supplies isolated TLS).
Release ARM64 APK in 3m04s, original package/version/signer checked:
`data/artifacts/chorvam-partner-panel-20261111/app-release.apk`, SHA-256
`64c68c5c8414b2af376577cc2ea9f72acb8f16365a0e51eed4ebfbd494cb918f`.
All new profile/weight records were synthetic; no measured-animal accuracy claim.
New account/roles/CLI draft files may already exist but are **not** part of this
milestone/test claim. Next: item 5 register/test these roles and password login.

**Item 3 published: 5ad683e**, audit 0 findings, origin/main ahead/behind 0/0.
Last log: 5ad683e / a20a9f2 / d422ea2. Working tree contains item-4 drafts.
**Item 4 in progress:** small server-side UZ/RU panel, existing bearer exchange
into opaque short-lived Secure/HttpOnly/SameSite browser cookies, CSRF checks,
no browser key storage. Jinja2 already pinned in Linux closure; now a direct
dependency. Additive 0008 is justified: browser session state and append-only
compact field summaries for explicitly synchronized tag/AR/scale records.
No raw depth is uploaded; local original evidence stays unchanged. Panel shows
only synchronized server data and never invents missing mobile weights.
Targeted summary lost-reply/reopen test passes; raw AR bytes unchanged, no depth
in the request. Tag/valid repeat-set/standalone scale records are supported.
Isolated PostgreSQL evidence:
`data/verification-backlog-20261111/evidence-panel-458fddd9ee5f4edfa8e2c0d333e56d1a.json`.
UZ/RU SSR tag search, immutable summary replay/delete rejection and Secure cookie
issuance directly verified. Actual HTTPS browser cookie roundtrip belongs to
item 6; current cookie behavior tested using HTTPS TestClient, not a phone.
Finance edits reuse existing expected_version/status/reason audit endpoint;
currently admin-only, bank_officer authorization follows in item 5.

**Backlog item 3 complete — 2026-11-11.** Built: revocable public slaughter
QR, private management/share/cache, four-language public whitelist page and
shared database rate limits. Directly verified: analyzer clean, **194 Flutter
tests**, **233 backend/tool tests**, Ruff clean. Isolated PostgreSQL/API proof:
`data/verification-backlog-20261111/evidence-qr-42a7027f234d4ca28b48b8072715a417.json`;
PNG decodes to exact URL; public page contains no owner/GPS/price/notes;
revocation makes URL 404 and database rejects deletion of its evidence.
Release ARM64 APK (3m16s), original package/version/signature verified:
`data/artifacts/chorvam-public-qr-20261111/app-release.apk`, SHA-256
`ef8e21c08b7273c72ea6cbff68bd972a73de94ea12e395403b959b8f4fc7502f`.
Synthetic-only: all new QR/health/ownership fixtures, including generated
QR PNG under mobile/test/fixtures (not a real capture). Phone/share-target
runtime unverified. External HTTPS domain not provisioned; public_origin
intentionally empty outside the isolated loopback stack.

Docker dependency verification reused a tagged, previously verified CPU
runtime (`chorvam-verified-cpu:20261111`) to avoid a very slow full Torch
download. Full new source and Alembic 0007 were actually built/run; all **64**
installed pinned distributions matched requirements-docker.lock, pip check
passed. This is not a claim of a fresh cold-cache build. Optional build argument
does not change the default pinned clean Python base. No normal stack changed.
QR UI loading indicator now precedes long instructions, preventing accidental
actions before cached receipts load. Host widget waits handle asynchronous
localization/disk IO without weakening AR assertions. All four 320px/200%
QR widget tests pass. Next: item 4 authenticated UZ/RU web portal, then 5–9.
Unregistered draft portal files may already exist locally; they are **not**
part of this QR milestone or its test claims.

**Current backlog item 3: revocable public slaughter QR (being tested).**
Items 1–2 published: d422ea2, a20a9f2. Post-item-2 status directly checked clean,
ahead/behind 0/0; log: a20a9f2 / d422ea2 / 34fd2b1. Item 3 uses additive 0007
immutable code/revocation tables + shared PostgreSQL fixed-window rate counters.
Default public_origin is intentionally empty (no invented reachable domain);
explicit localhost origin only on the isolated verification stack. Public
whitelist excludes owner, GPS, prices, actors, notes and photos. Codes require
server-recorded slaughter; badge/date only from unsuperseded vet-role records
once item 5 exists. Python-qrcode 8.2 BSD license retained in NOTICE/licenses;
Pillow reused, no Flutter library added. Mobile caches receipt/QR, marks offline
status unverified, shares PNG, and supports explicit revocation with durable
intent/replay. QR test PNG is generated, synthetic .invalid URL, not animal data.
BuildKit pip cache now avoids re-downloading the CPU runtime on each new pilot
dependency; runtime remains pinned and `pip check` retained.

**Latest: backlog item 2 built/directly verified (2026-11-11), publishing now.**
189 Flutter tests + analyze clean, 230 backend/tool tests + Ruff clean;
isolated PostgreSQL transfer/replay/stale-version/price audit passed.
ARM64 APK built in 3m48s, package/version/original signer preserved:
`data/artifacts/chorvam-ownership-20261111/app-release.apk`, SHA-256
`79d20d567df63972707962b0de750a3b3517f256f30645cf94293414f8b5bd46`.
New ownership math/IO/forms remain synthetic-only; phone runtime unverified.
Next backlog item is 3 (revocable public slaughter QR), then 4–9 in order.

**ACTIVE 2026-11-11 nine-item backlog:** health → offline sale/ownership →
revocable public slaughter QR → UZ/RU web portal → role/password sessions →
isolated production deployment kit → onboarding → isolated demo flavor →
truthful roadmap/architecture/pitch status. Current request attachment:
4a74362c-75b8-475e-840d-b895e1e8d545. Entry 34fd2b1 clean; live fetch 0/0.
Milestone pushes authorized for this project only; no force/rebase. Every item:
Flutter analyze/test, APK+SHA (ignored), backend pytest/Ruff when touched,
isolated 18001 Docker verification, publication audit, commit/push, progress.
No phone installation, real-data/normal-stack changes or purchases.
Current item 1: additive migration 0006 is needed for append-only health events
and immutable correction chains. Reuse registry transactional idempotency receipts.
Until item 5 adds verified roles, all records are operator reports, including
those with a typed veterinarian name. New health config stays outside AR hash.
The previous five-stage status below is historical, not the current stop point.

**Backlog item 1 built/directly verified — 2026-11-11:** offline health timeline,
four event kinds/date/description/optional veterinarian/notes, immutable corrective
records, explicit MAA sync with durable intent/receipt and parent-first correction
ordering, ZIP `ledger/health.csv`. Cattle business config v7, unrelated health
limits excluded from the unchanged AR correction cohort hash; sheep unchanged.
New additive migration 0006 creates health events, one correction successor,
unique actor/local-event key and database UPDATE/DELETE rejection triggers.
All records deliberately labeled Operator record until item 5 adds vet roles.
Direct checks: **183 Flutter tests**, analyze clean; **228 backend/tool tests**,
Ruff clean. New tests include 4-locale 320px/200% timeline/form, lost reply/reopen,
correction/export persistence, request validation and replay/role spoof rejection.
These are synthetic software checks, not clinical/dataset/phone verification.
Dedicated stack `chorvam-backlog-20261111` on localhost 18001 uses its own new
volume, data/verification-backlog-20261111 storage and random synthetic credentials.
Actual HTTP upload/replay/correction and SQL UPDATE/DELETE rejection verified:
`data/verification-backlog-20261111/evidence-health-c3cde29f4f2b43c79b6797386e75b1dc.json`.
Normal stack/real IDs untouched. Initial migration/model index mismatch was
caught by tests and fixed; full final suite passed. One restricted host pytest
run stalled and was replaced by the verified full run. ARM64 release built in
7m26s, original package/version/signer checked; no phone install/runtime claim.
Artifact: `data/artifacts/chorvam-health-20261111/app-release.apk`; SHA256SUMS.txt
in the same ignored folder. Publication audit/commit/push follows, then item 2.

Item 1 publication completed: d422ea2; audit zero secret/credential/phone findings,
clean `## main...origin/main`, ahead/behind 0/0. Actual log:
```text
d422ea2 Add append-only offline health history and idempotent registry sync
34fd2b1 Record verified five-stage push state and final artifact evidence
42c63ee Document Uzbekistan pilot hosting, current privacy rules and field verification gates
```
APK SHA-256 `fd2cf8ed8ef10bbca95dd40ddf6c4d4005a1d270fe4c386fcf48e7fc131dfc54`.

**Current item 2:** append-only offline ownership/sale events with optional whole
UZS price, predecessor chain, owner/date/reason, and explicit MAA synchronization.
Existing owner endpoint gains optional price/currency; omit absent new fields
from canonical request hashing so historical receipts remain replayable. No
new database table/migration needed: owner changes already use immutable audits.
Freeze expected_version BEFORE HTTP and reuse existing RegistryJournal receipts;
on conflict do not rebase intent/change key or silently overwrite a newer owner.
Day-only dates are transmitted as UTC midnight representing the entered day,
not a claim of a measured event time. Price/ownership remain operator reports.

Item 2 checks so far: **189 Flutter tests**, analyzer clean; **230 backend/tool
tests**, Ruff clean. UZ/RU/Cyrillic/EN 320px/200% owner forms pass after making
long dialog title/content jointly scrollable (RU overflow was caught/fixed).
Dedicated PostgreSQL proof:
`data/verification-backlog-20261111/evidence-ownership-e5d9d58acd7a4914907cd54e6d430b31.json`.
HTTP replay preserves one transfer, stale version rejected, optional UZS price
present in immutable audit. Existing absent-price owner hashes remain identical.
Health replay now runs before configurable text limits to preserve accepted
receipts if future limits become stricter (regression tested).
Publication audit now uses Git batch object reads, still checks all current
tracked paths plus outgoing blobs. Compared against the archived d422ea2 audit
under its original immutable base: all findings/coverage/ignore checks equal.
This saves hundreds of Windows process startups without reducing checks.

Upcoming implementation choices, **not built yet**: item 3 QR generated on the
server with pinned python-qrcode 8.2 (official PyPI/repository BSD-3-Clause
checked), reusing Pillow and decoding test with existing OpenCV. No new mobile
library needed; QR only from server-recorded slaughter, opaque random token,
append-only revocations, strict public-field whitelist, shared DB rate windows.
Require configured public origin rather than inventing a reachable domain.
For item 4 SSR panel, secure short-lived token-to-cookie session foundation
can precede item 5 password users/roles; never put bearer keys in URLs/storage.
Item 5 adds Argon2/bcrypt login and authoritative roles with CSRF protection;
operator-entered vet name must never imply vet verification. Future UX cleanup
should group health/ownership actions with profile actions rather than under
the measurement heading. All code-independent fields/accuracy remain unverified
on a phone. No current architectural decision requires Sardorbek.

**Five-stage task completed — 2026-11-10:** implemented the attached continuation
with the user's overriding instructions. Stages: (1) Chorvam label/splash/original
adaptive vector icon, (2) bounded burst best-frame capture and review,
(3) separate weight-training side photos linked to dated real scale weights,
(4) append-only local L→server MAA registration/replay/upload, (5) sourced
pilot-server plan only. Preserve package/signing/storage, existing AR modes,
all strict journals and disabled sheep. No external AI service or paid work.
User reports 23117RA68G cannot use ARCore; keep optional AR for other devices.
**No adb/install/device checks in this task; phone runtime remains unverified.**
User now explicitly authorizes ordinary origin main pushes after milestones.
Stop for remote-only commits or any discovered secret; never rewrite history.
Public repository/remote ancestor and all 33 initially outgoing commits audited; see
docs/PUBLICATION_AUDIT_2026-11-10.md. No secrets/personal phone numbers or real
owner records found. Feature milestones published as 091a66f, 6b04d79,
3fb1324 and 655b8ee; server-plan documentation published as 42c63ee. Entry main was
clean at 5910f35, remote eaaf857. See actual post-push evidence below.

**Next action is a field check, not more model claims:** manually install the
latest ignored `data/artifacts/chorvam-pilot-ready-20261110/app-release.apk`
when desired, keeping the existing app/data. Try burst on 5–10 cattle, record
attempt/completion/rescan outcomes with denominators, confirm every image's ID,
collect left/right body photos and same-day actual scale kg/date if possible.
Verify persistence/review/gallery/ZIP after reopening. No APK was installed by
this session. 23117RA68G ARCore unsupported is founder-reported; preserve AR for
supported phones. Backend operator credentials must match original scan metadata
before explicit registration/upload. Do not relabel old operator evidence.
YOLO checkpoint, calibrated matching/weight accuracy and new native runtime
remain unverified/externally data-dependent. Sheep stays disabled.

**Stage 1 complete — 2026-11-10:** Chorvam Android launcher label, native
splash icon/Flutter startup wordmark and in-app titles/backup wording. Original
forest/cream/amber adaptive vector muzzle icon. Package/applicationId, version
code, existing gallery album, storage and signing preserved. Direct checks:
150 Flutter tests passed; flutter analyze clean (initial command waited at
startup; explicit no-version-check retry also passed), audit-tool Ruff clean.
ARM64 release built in 9m9s; APK v2 and original signer verified. Artifact:
data/artifacts/chorvam-brand-20261110/app-release.apk; SHA-256
ae469628632e81db4fafe4b444f85a030f107d10aced454106abc11826123cd0.
All bundled config/catalog bytes match source. Phone runtime and retention
after this update: **unverified**, no adb/install/device access performed.
Published as 091a66f by ordinary fast-forward push; evidence follows.

**Stage 1 push directly verified:** after publication, status was
`## main...origin/main` (clean), `git rev-list --left-right --count
HEAD...origin/main` returned **0 / 0**. Real `git log -3 --oneline`:

```text
091a66f Brand Android capture app as Chorvam and audit public publication
5910f35 Research Chorvam market demand and refine accelerator application
ac1a091 Review Chorvam accelerator pitch and record six-cattle founder trial
```

**Stage 2 built and host-verified:** selected original-resolution YUV stream candidates
are JPEG-encoded, receive the existing full JPEG QC, and are staged durably
with frame/time/quality/count provenance outside strict upload JSON. Each
selected frame runs an independent existing identity confirmation; no group
ID inheritance or automatic multi-photo binding. An automatic safety review
rejected the initial group-binding proposal; it was replaced with individual
confirmation. Cattle business config v5 adds bounded 4-second/top-3 capture;
AR policy digest remains v3 and sheep unchanged. Existing official camera
BSD-3-Clause + image MIT reused; original selector, no new MP4 dependency.
Direct checks: analyzer clean, all **158 Flutter tests**, **224 backend tests**
and Ruff passed. Synthetic-only: sharpness ranking, original-buffer ownership,
strides/rotation/JPEG dimensions, threshold/cadence/exposure/small-stream gates,
durable multi-frame review and 4-locale 320×720/200% layouts. No camera stream,
device speed, moving-cattle sharpness or matching accuracy claim.
ARM64 release and original signer/package/version verified; artifact
`data/artifacts/chorvam-burst-20261110/app-release.apk`, SHA-256
`a234a4981d16ac83e4180102a6a8a3da24f2c4629e45542b05f75ae9611109af`.
Phone runtime **unverified**, no device access. Next: separate side photos.

Stage 2 ordinary push directly verified: clean `## main...origin/main`,
ahead/behind **0 / 0**; real log at that point:
```text
6b04d79 Capture and review sharp original burst frames with per-photo identity confirmation
091a66f Brand Android capture app as Chorvam and audit public publication
5910f35 Research Chorvam market demand and refine accelerator application
```

**Stage 3 built and host-verified:** separate `side_photo` immutable events/originals,
never muzzle scan/checklist/matching/research items. Date-linked actual scale
observations, 7-day per-photo config snapshot; no photo weight model. Profile
has left/right capture, mirrored original silhouette and configurable 3–4 m
guidance. Original bytes/hash and append-only event survive ZIP/restart;
`ledger/side_photos.csv` derives nearest actual scale record at export time
(inclusive UTC calendar-day boundary; latest revision resolves equal gaps).
Cattle config v6; AR correction-policy digest unchanged; sheep unchanged.
Direct checks: **165 Flutter tests**, analyzer clean, **225 backend tests**,
Ruff clean. New linkage/exclusion/hash/export tests and 4-locale 320px/200%
guidance are **synthetic-only**; phone capture/scale pairing in field remain
**unverified**. ARM64 release built, package/version/original signer checked.
Artifact `data/artifacts/chorvam-side-photos-20261110/app-release.apk`;
SHA recorded in its SHA256SUMS.txt (ignored). No device access.

Stage 3 APK SHA-256: `2aa725de2c89cba4e9777e324404948116a9619104828379f000fb9fd2d38548`.
Stage 3 ordinary push directly verified: clean `## main...origin/main`,
ahead/behind **0 / 0**, real log:
```text
3fb1324 Collect separate body-side photos linked to dated true scale weights
6b04d79 Capture and review sharp original burst frames with per-photo identity confirmation
091a66f Brand Android capture app as Chorvam and audit public publication
```

**Stage 4 built and host-verified:** deterministic issuance key from species + random local
L label (independent of endpoint/operator changes; existing registry journals
fail closed on scope change). Frozen owner intent, existing registry receipt
replay, append-only mapping; derived MAA upload original + new strict journal
with a raw link to untouched L evidence. No automatic/background registration.
Upload keeps original operator/GPS/time; credentials must belong to that operator.
No backend schema/API change needed. No device/normal stack write.
Profile registration panel and Tools multi-select require explicit action;
first owner reference/name is retained in local intent. New registration and
derived-upload CSVs/raw receipts survive verified ZIP export/restore. The same
local label under another operator/endpoint cannot silently allocate a second
request key. A known rejection remains a rejection, requiring review rather
than rotating the key. Old L scan/JPEG/journal bytes remain unchanged.
Direct checks: **177 Flutter tests**, analyzer clean, **226 backend/tool tests**
and Ruff clean. Synthetic-only: owner form/confirmation, independent labels
sharing owner, issuance/upload lost-reply replay, accepted receipt before
mapping recovery, concurrency guard, source-hash/operator mismatch, offline
credential gate and all four 320px/200% registration layouts. Initial owner
widget waits were corrected to await disk IO and inspect SelectableText;
final full suite passed. Existing PostgreSQL contracts were reused, no new
live server integration/deployment claim. Phone runtime **unverified**.
ARM64 release built and original signer verified; artifact
`data/artifacts/chorvam-registration-20261110/app-release.apk`, SHA256SUMS.txt.
Next: documentation-only pilot server plan, then final publication evidence.

Stage 4 APK SHA-256: `c83163495a8dcf834cd1c8b99e08df9fbc17e868fb8796f3413b559c56a04cae`.
Repeated publication audit at 655b8ee: 321 tracked paths, zero forbidden/
credential/personal-phone findings; ignored raw report retained in data/dev.
Stage 4 ordinary push directly verified: clean `## main...origin/main`,
ahead/behind **0 / 0**; real log:
```text
655b8ee Register local cattle IDs with durable replay and immutable derived uploads
3fb1324 Collect separate body-side photos linked to dated true scale weights
6b04d79 Capture and review sharp original burst frames with per-photo identity confirmation
```

**Stage 5 documentation completed:** sourced Uzbekistan VPS/HTTPS/backup/security
plan only. Current Lex.uz 27¹ uses the March 2026 revision, not the obsolete
blanket 2021 localization claim; owner/operator/GPS privacy is separate from
animal images. UZ-local primary+backup is the proposed simple pilot choice.
No purchase/account/deployment/contact or real-data movement. Provider prices
are dated offers/calculator output, not measured SLA or a contracted quote.
`docs/PILOT_SERVER_PLAN.md` proposes approximately 570–890k UZS/month for
server + separate backup (dated estimate, excludes domain/operations), flags
development credentials/Compose exposures and distinguishes proposed RPO/RTO
from tested guarantees. Current endpoint and original data were not touched.
Final repeated host checks: **177 Flutter tests**, analyzer clean; previous
current backend/tool suite **226 tests** and Ruff clean. ARM64 build succeeded;
APK's four config source bytes/hashes and all four locale catalogs were checked
inside the actual ZIP, plus manifest/version/package and original APK signer.
Phone runtime **unverified**; registration IO/UI and quality math remain
synthetic verification, not field accuracy. Final artifact and SHA256SUMS.txt:
`data/artifacts/chorvam-pilot-ready-20261110/` (ignored).
Final APK SHA-256:
`c83163495a8dcf834cd1c8b99e08df9fbc17e868fb8796f3413b559c56a04cae`.

**Stage 5 post-push evidence (directly executed 2026-11-10):**

```text
git status --short --branch
## main...origin/main

git log -3 --oneline
42c63ee Document Uzbekistan pilot hosting, current privacy rules and field verification gates
655b8ee Register local cattle IDs with durable replay and immutable derived uploads
3fb1324 Collect separate body-side photos linked to dated true scale weights

git rev-list --left-right --count HEAD...origin/main
0  0

git remote -v
origin https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

All five stage pushes were ordinary fast-forward updates. This last documentation
commit records the observed post-stage-5 snapshot; it changes no APK/code. Final
live clean/ahead-behind check is repeated after publishing this evidence commit
and reported to Sardorbek, avoiding a self-referencing commit-hash loop.

Historical sections below describe their own dates; this current five-stage
summary overrides obsolete SDK/phone blockers and earlier planned-only wording.

**Latest field correction / market research — 2026-11-07:** Sardorbek
clarified his earlier six-animal report: the trial was **2026-11-06** and
only **2 cattle were properly tested**, with moving cattle making sharp
capture difficult. Do not reuse the PDF's 'six successfully recognized'
claim or invent 2/2 accuracy. Matching attempt counts/outcomes remain
unrecorded; this is founder-reported early field/usability evidence.
Capture completion and motion handling are the next validation priority;
short-video best-frame capture was planned then and is now built in Stage 2 above.
Market/application research in docs/CHORVAM_MARKET_AND_APPLICATION.md:
government VIS-CHINOR exists; position a proposed complementary offline
inspection workflow rather than a first national registry. Primary sources
show sector financing, institutional digitization and foreign identity/
insurance partnerships, not paid demand for Chorvam. No organization was
contacted or form submitted. Existing app and user data are unchanged.

**Pitch / product update — 2026-11-07:** Sardorbek chose the public brand
**Chorvam**, with a whole-life cattle-passport vision: birth/growth/health,
ownership/sales, insurance/collateral support and slaughter history. Reviewed
all 12 pages of his PDF visually and against current code evidence; see
docs/CHORVAM_PITCH_REVIEW.md for corrections, usable copy and official sources.
No app/package/storage rename or feature implementation was requested in
this review. Supplied PDF unchanged; no application/message submission.
**Initial report, superseded by the correction above:** Sardorbek said he tested with **6 real cattle**;
the PDF reports offline registration and rescan/profile lookup. We have not
independently examined the trial logs, images or attempt counts. Earlier
'no real-animal trial' notes are superseded by this founder report, not by
an independently validated accuracy claim. No 100% identity/weight guarantee.
Video best-frame extraction, veterinary/birth/growth modules, marketplace,
full automatic local-passport sync and bank/insurance integrations remain
future capabilities. Current L-ID upload needs explicit permanent registration.
Official accelerator rechecked: deadline 9 Nov 2026 and stated 2–5 founders;
Sardorbek remains solo, eligibility clarification is still outstanding.
Next application work: qualify claims/statuses, add real screenshots/trial
counts, resolve funding placeholder with a costed ask and prepare demo.

**Offline profiles and advisory rescan — 2026-11-06.** Main screen now opens
one native-camera scan flow with the existing quality gates; from a match
warning or manual lookup, only the operator can confirm an existing ID.
Otherwise the new-animal form allocates a local L-ID. Interrupted assignments
retain the original photo and replay only the chosen ID. Profiles keep all
sessions/photos, both formula estimates, latest rate and ranges, and dated
scale observations. Completed valid AR sets already save to the local ledger
and now refresh the profile on return. Lists use capture-date ordering and
hash-keyed 160px thumbnails; raw Depth/JPEG events are not decoded for lists.
Previous P0/manual authenticated upload and AR fast/contour/snapshot workflows
remain available. Cattle business config v4 adds advisory gates; the separate
AR policy digest stays v3 to preserve existing correction cohorts. Sheep is
unchanged and disabled.

**Duplicate review is experimental.** Android uses official OpenCV
`org.opencv:opencv:4.13.0` (Apache-2.0 license shipped in the APK, see NOTICE).
Original Kotlin code uses grayscale center ROI, ORB descriptors, Hamming
Lowe-ratio matches, RANSAC inliers and per-ID top-3 ranking. Cached descriptors
are keyed by policy and source image SHA-256. There is no model checkpoint,
identity assertion, auto-link, merge, or accuracy percentage. Case/space
normalized tag collisions get a separate confirmation. Raw append-only
evaluations/decisions and `ledger/match_decisions.csv` record the rule hashes,
scores, session and human decision, including manual matches with no warning.
Tools denominators count only adjudicated new/repeat scans.

**Direct phone release verification.** ARM64 signed APK
`data/artifacts/profiles-advisory-20261106/app-release.apk`, **47,821,782 bytes**,
SHA-256 **0e185a9995a085e0f5d9c04b2b2531a1cef3072f29dd67f64bbe6824b2a90275**.
Android package and version code unchanged, APK v2 and same Android Debug
signer verified; no token included. Four YAML configs, manifest, four locale
catalogs and OpenCV license verified byte-for-byte. Build: from `mobile/android`,
`./gradlew.bat :app:assembleRelease -Psplit-per-abi=true -Ptarget-platform=android-arm64 -Pforce-version-code-ignoring-abi=true`.
`adb install -r` succeeded on **23117RA68G** Android 16 and cold launch was OK.
UI dumps `data/dev/advisory-device-{home,roster}.xml` show the new scan button
and original **L-08950445754DD715 / TEST_NOT_CATTLE** retained in Mollarim.
No application data reset, no backend deployment, no push.

**Synthetic verification on 23117RA68G.** Separate `.probe` APK, with gallery
copy disabled, ran real OpenCV on 30 synthetic identities × 6 JPEGs. Three
warm requests completed in **1.299 / 1.335 / 1.320 s**, 180 compared,
181 cache hits including the query, no extraction or failed photos; cold
request with 180 extractions took **6.331 s**. Exact image: 512/512 inliers;
rotated/cropped: 256/265; unrelated texture and deliberately strict threshold:
no warning. Isolated empty roster → 3 local IDs → native comparison →
simulated human confirmation → reopen same ID with 2 photos and still only
3 animals. No synthetic images were added to the production roster or album.
Raw report: `data/artifacts/profiles-advisory-20261106/synthetic-phone-probe.json`.
To rebuild the probe, use the ARM64 command above plus
`-PbiolivestockProbe=true -Ptarget=tool/advisory_device_probe.dart`;
verify the APK package suffix `.probe` before any install. These synthetic
results verify the mechanism and timing, not accuracy on animals.

**Host verification:** Flutter analyzer clean, **150 Flutter tests** (including
the scan/confirmation/restart widget flow, all four locales at 320×720 and
200% text for profile/roster, immutable scan evidence, AR digest compatibility,
and ZIP ledger), **221 backend + 48 research tests**, and Ruff clean. See
`data/dev/advisory-{flutter-verified,analyze-verified,backend-final,research-final}.log`.

**Field next step:** follow the updated [offline field guide](docs/OFFLINE_FIELD_GUIDE.md):
enroll each actual animal with separate muzzle photos, then intentionally
rescan 5–10 verified identities; manually confirm correct IDs even when there
is no warning. Compare actual AR results to scale values only after checking
the phone's ARCore/Depth availability. Real cattle matching, weight accuracy,
Depth capture, and real camera/GPS/gallery behavior in the new workflow have
not been verified in this session. Synthetic tests are kept out of the
production roster.

**Phone ID proof complete — 2026-11-05:** user created `TEST_NOT_CATTLE`, app automatically issued **L-08950445754DD715**. Actual before/after XML `data/dev/device-roster-{pre,post}.xml` shows exactly the same ID+tag after force-stop/cold start, no app data reset. Offline operator SARDOR-01 visible. AR screen probed on 23117RA68G Android16: `UNKNOWN_CHECKING`, `Depth ?`, `AR ?`; com.google.ar.core absent initially. Do not claim unsupported or real Depth capture from this. Restored global USB stay-awake to 0. No cow/image/weight was acquired. Snapshot UI milestone **f02ff8d**. Starting My Cattle/profile/advisory implementation below. Official OpenCV Android Maven artifact `org.opencv:opencv:4.13.0` and tag license verified; native adapter will use original OpenCV ORB/KNN/RANSAC code, no external models/account, preserve ARCore optional path.

**Active next request — 2026-11-05:** after checking local ID persistence on the phone, implement the user-approved offline **My Cattle / profile / one Scan Animal** workflow plus **advisory ORB duplicate candidates**. This supersedes the earlier open QR/manual-vs-matching question: no QR, no definitive biometric recognition or automatic ID/link/merge. Main camera→existing QC→advisory top-3→operator confirms existing (new visit/group, same ID and profile), rejects/chooses new (auto local L-ID, optional tag/notes, profile), or manually chooses an existing animal even with no warning. Empty roster goes straight to new registration. Profile latest weight auto-updates from a completed saved AR set, both formulas/date/mode, price range/latest dated price and scale weight, all photos/history/prices, new photo/AR/scale buttons. Searchable newest-first compact roster, latest thumbnail/ID/tag/weight/date; cached resized thumbnails and no bulk depth/base64 parsing to display list. Preserve legacy authenticated/P0 and all snapshot/fast/contour flows. User approved native official OpenCV ORB (or permissive package); verify exact SDK/source/license. Grayscale + center ROI, Lowe ratio + RANSAC inliers/ratio; config-only thresholds and feature sizing, hash-keyed descriptor cache, per-animal best score, top3; explicit uncalibrated advisory signal, no accuracy percentage. Normalize tag case/whitespace, warn separately. Append-only evaluation and decision evidence incl manual missed-match adjudication; ZIP ledger/match_decisions.csv, Tools repeat-found/missed/new false-warning counts with denominators. Target 3s on 30×6 warm cached phone comparisons; prove on device or mark unverified, never fake benchmark. Tests same/rotated/cropped/different texture and full empty→3→rescan→same-profile flow; physical no cattle today, distinguish synthetic from real. Four locales/320×720 at 200%, tests/build/SHA/new artifact and install -r only. No data deletion or push. Update guide with enroll all then intentionally rescan 5–10 and compare human-confirmed identities.

**Snapshot milestone — built and host-verified, installed on actual phone (2026-11-05):** default left/right frozen four-point frames + optional front two-point width. Raw viewport JPEG and complete same-timestamp uint16 depth/uint8 confidence, camera pose, intrinsics, display mapping and hashes persisted before annotation; append-only annotation/retake/cancel plus within-frame pixel→metric unprojection, no future-frame hit tests. Left/right raw values, mean geometry, 5% repeat gate and two formulas; exact front width bypasses N3, otherwise reuse/append immutable median ratio of distinct eligible same-species/breed fast records, including v2. Correction separates width source and ratio key; unchanged ratio cohort stable (synthetic ten-animal correction verified). Original mirrored vector, plain point names, four locales. CSV/ZIP includes frame/provenance and selected pixels, raw binaries retained only in JSON/ZIP; history shows JPEG without rendering base64 as text. Backend additive cattle v3, legacy/disabled sheep preserved. Domain commit **2f57cbf**; native/UI local milestone follows. Source reference PNG supplied by user, runtime vector original; official ARCore 1.54.0/API references in NOTICE. No native package/signing changes.

**Direct checks:** final Flutter **143 passed**, Python **265 passed**, Flutter analyzer and Ruff clean; final `flutter build apk --release` **73.1s**, APK v2 signature Android Debug certificate `8e43cfb55a120f18a62cf955d19a5ed40816f34a96c1416b27644b08de500c90`. Final ignored artifact `data/artifacts/snapshot-multiview-20261105/app-release.apk` 61,942,436 bytes, SHA-256 **777dfd8a8154a176f6c40220b9a4d6a272381d5793f78bcd3728c1525d592f19**. Four bundled YAMLs and four locale catalogs byte-verified. Evidence and logs under artifact folder and `data/dev/snapshot-{flutter-persist,python,analyze-persist,build-persist,signature}.log`. No API token. Preserve Nov4 artifacts too.

**Physical evidence and exact immediate next action:** phone **23117RA68G**, Android **16/API36**, USB connected after initial empty probe, `adb install -r` returned **Success**, cold MainActivity launch **Status ok** and offline bundled capture UI visible. User entered `SARDOR-01` and actual Tools screenshot showed it saved. Package `com.google.ar.core` absent at initial check; ARCore eligibility/Depth not yet established, no actual AR capture/weight or muzzle photograph performed. Device USB stay-awake temporarily set for testing from initial global value **0**; restore **0** at end. No airplane toggle, uninstall or clear-data. Remote clicking the enabled New Animal button wasn't reliable; asked user to make one explicitly labeled `TEST_NOT_CATTLE` local record (no photo). Once confirmed, record actual L-ID, force-stop/relaunch without clearing app data, check same label/operator still present, probe AR when possible; keep synthetic record clearly marked, no fake animal data. User has no cattle today and will use the phone app itself tomorrow, capturing each photograph separately. Later goal is automatic camera recognition, but current APK does not recognize animals; the next implementation is user-confirmed advisory ORB only. Preserve user's real data, no automatic selection or merge.

**2026-11-05 snapshot work in progress (supersedes the Nov4 default-mode description):** entry tracked tree clean at 238116d, only user-supplied docs/design/mol-olchash-nuqtalari.png untracked. Read current progress/field guide and AR math/records/native/UI. Implemented default frozen left/right four-point mode with optional two-point front width, raw-depth/confidence exact-frame timestamp gate and original mirrored vector guidance using plain four-language terms. Every segment is intra-frame; final side length/depth averages and 5% repeat gate, median width ratio from N≥3 distinct same-species/breed valid fast animals (including legacy v2), no fake ratio/fallback. Important revision fix: unchanged source/policy reuses the immutable ratio key, so ten-animal weight-correction cohorts can accumulate; changed ratio sources/policy generate a new append-only revision and separate correction group. Front-vs-learned and ratio revisions never mix. Snapshot JSON/CSV/ZIP, retake/undo and ordinary valuation/scale paths integrated. All 265 Python tests and 17 targeted Flutter cases passed; new ten-snapshot correction-cohort test plus full final Flutter/analyzer/release are being verified. First native build passed 488.5s, but later source/preview fixes require final refreshed APK/signature/hash. adb list remains empty; no physical-device or real-animal claim. Root-scope analyzer accidentally scanned ignored scratch files; authoritative checks run from mobile/. Older Nov4 APK stays preserved. No push or data reset.

**Latest completed state — 2026-11-04 (supersedes the older in-progress notes below).** P0 and P1 code, local milestones and the release APK are complete. P0 commit **7a892a8**; AR domain/config/ledger **9ef25c3**; native ARCore/four-language UI/guide **47a5411**. No push. This is an implemented, host-tested field tool, not proof of animal measurement accuracy or native phone behavior.

| State | Evidence / boundary |
| --- | --- |
| Built | Fresh-install token-free offline cattle collection, operator preferences, provisional L- labels/tag/Unicode notes, six-view session ledger, immutable original/queue and gallery copies; optional Android native ARCore screen, default six-point fast mode and separate ordered closed contour; repeated measurements, both weight formulas, local prices/valuation, actual scale-weight dates and versioned optional correction. |
| Directly verified on this machine | Full **130 Flutter tests**, **262 Python tests**, Flutter analyzer and Ruff clean. Final `flutter build apk --release` succeeded **338.7s**. apksigner verifies v2, CN=Android Debug, same certificate as P0. All four embedded YAML configs and all four translation catalogs byte-match source. No API_TOKEN define supplied. No database migration, normal-stack deployment, Docker rerun, cloud/API inference or data reset in this work. |
| Synthetic only | Eight AR domain tests: Python golden 180/150 dairy→540 kg, Schoorl→408.04 kg, rotated planar contours, bad geometry/confidence/tracking/scale, ellipse circular limit, repeat limits/mode isolation, distinct-animal minimum-N median/MAPE, exact integer UZS and hashed ZIP/CSV. Five AR widget tests include four locales at 320×720/200% text plus two fake-native runs→price→valuation→restart. These do not exercise Android camera/ARCore hardware. P0's actual Dart JPEG/QC/restart/ZIP probe and independent Python recovery are retained below. |
| Genuinely unverified | Native camera/gallery permission and album behavior, Android AR/OpenGL/depth/confidence/anchor behavior, actual airplane-mode install/restart/share, iOS build/runtime and real animal formulas/landmark accuracy. An APK compiling is not device verification. |
| External next input | Elevated `adb devices -l` at final check returned **empty**. Sardorbek reports a working phone, but no connected model/Android/AR service/Depth evidence was available. Current support is **unknown**, not unsupported. Real cattle identity sessions, muzzle checkpoint and measured animals/scale weights remain absent. No routine architectural question pending. |

**Final personal-install APK:** `mobile/build/app/outputs/flutter-apk/app-release.apk`; preserved copy `data/artifacts/offline-ar-20261104/app-release.apk`, **61,807,736 bytes**, SHA-256 **e7f596e8cfa114a1a78dd793533642dc425acfc8f15f77e72d20e902922f8b24**. Build/token/source-asset evidence: `data/artifacts/offline-ar-20261104/evidence.json`. Signer certificate SHA-256 **8e43cfb55a120f18a62cf955d19a5ed40816f34a96c1416b27644b08de500c90**; debug key is suitable for this personal sideload, not production signing. Final logs: `data/dev/ar-{flutter-full,python-final,analyze-final,build-final,signature}.log`. Artifacts/logs are ignored by Git. Known upstream TestClient/httpx deprecation and Java native-access warning only; successful commands exited 0.

**Exact next action:** follow `docs/OFFLINE_FIELD_GUIDE.md`, install/update with `adb install -r` or open the copied APK; never uninstall/clear data. While online prepare Google Play Services for AR and camera permissions, then inspect the app's actual device probe. In airplane mode, create/select one provisional animal, take six muzzle views, verify album/originals after restart, attempt two fast AR measurements (or confirm an actual unsupported/services-required explanation), enter a real market observation, save valuation and export/share ZIP **off the phone**. If AR is unsupported, continue P0. Only then try consented stationary adult cattle with a handler and actual scales; do not present synthetic MAPE as validation. No physical-device installation/test was performed here.

**P1 scope/limits:** anatomical points are selected by the operator, not an AI keypoint detector. ARCore supplies real metric world points; no 2D scale/depth/reference is invented. When Depth is available use depth hits with same-time raw-depth confidence/depth agreement; otherwise require a nearby current real point-cloud confidence. Planes/Instant Placement are not used as animal geometry. Tracking loss/interruption, anchor drift, timeout or low confidence fails the attempt. Object motion/breathing is **not assessed**; the handler must keep the animal still. Completed/returned failed attempts retain raw data; an Android process killed during an unfinished native run cannot guarantee recovery of those unfinished points. Already committed P0 queue records remain intact. For a new visit or changed animal condition, start a new repeat set rather than adding a third run to an old set.

**Local evidence:** `field-measurement-*.json` stores typed attempt/repeat_set/weighing/calibration/correction_choice/valuation events, raw meters/confidence/tracking, segment lengths, timing, config hash/snapshot, 1–2 embedded JPEG screenshots with frame metadata, and result provenance. Failed native attempts retain available partial JSON; invalid completed attempts remain marked invalid. `field-price-*.json` keeps append-only price revisions, date/source, optional live-weight price. Backup includes these raw files plus `ledger/measurements.csv` and `ledger/prices.csv`; CSV points to original JSON and never expands JPEG base64. Corrupt raw records are retained in ZIP even when omitted from readable CSV. UI/CSV history is not a substitute for raw evidence. Market prices are user observations, not a feed; prices/values use BigInt fixed-point and integer UZS. Cattle 50–58% carcass values are scenarios, not statistical confidence intervals or boneless-meat yields. The backend calibrated_3d/manual valuation/authenticated upload contracts are unchanged.

Live Git evidence immediately after the native/UI milestone (before the final progress-only commit):

```text
47a5411 Integrate optional native ARCore field measurement and offline valuation UI
9ef25c3 Add offline AR geometry, repeatability and versioned calibration ledger
7a892a8 Enable fresh-install offline cattle collection with provisional ledger and gallery copies
95fce87 Prepare Agrobank application and pilot proposal with founder eligibility gate
ffeb288 Consolidate complete project context and continuation prompt
origin  https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin  https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

**P1 domain milestone — 2026-11-04, native/UI final verification in progress:** P0 is complete in local commit 7a892a8; preserved release and evidence below. Added cattle business config v2 with optional backward-compatible AR settings; sheep unchanged/disabled. Original Dart metric geometry validates simple planar contours using Jacobi covariance axes equivalent to Python's SVD, never reorder/hull; six-point default fast mode uses Ramanujan II ellipse perimeter, explicitly uncalibrated. Original calibrated_3d backend contract is unchanged; native AR uses its own arcore_metric provenance without inventing a reference. Fixed-point BigInt formulas/money, 2–3-repeat max relative difference gate, append-only local price/weighing/calibration events, minimum 10 distinct labels, per-mode/breed/formula/config-hash median correction and in-sample MAPE are implemented. Eight domain tests passed including 540/408.04 golden values, rotated contour, invalid geometry/tracking, insufficient-N/mode isolation and hashed ZIP/CSV. Full existing Python suite 256 passed before six new AR config cases; those/new final suite still to run. Four-language 320px/200% unsupported pages and two synthetic native runs/price/valuation/restart passed. First native ARCore release compiled successfully (549.0s); subsequent marker/form/lifecycle changes still need final APK build and signature/hash verification. Phone still not connected; no hardware/animal accuracy claim. Next: finish final checks/docs, local milestones, no push.

**Active offline-field P0 then AR P1 work — 2026-11-04:** user supplied a concrete implementation request. Entry clean at 95fce87. Confirmed fresh install previously required backend/cache; implementing bundled byte-identical YAML, token-free local operator, clearly provisional L- namespace separate from canonical MAA, native QC/immutable queue, gal 2.3.3 gallery-copy-only (no picker), six-view/session sidecars and CSV ZIP exports. P0 must pass tests/release build/local commit before P1 implementation. User further specified six-point fast AR (length/depth/width, Ramanujan ellipse girth), separate closed-contour mode, versioned minimum-N correction/true-scale dates, repeatability and licensed-only rendering sources. Native implementation/accuracy still unverified. Elevated adb devices -l succeeded with an empty device list; no connected hardware model/Android/ARCore/Depth evidence, no install/reset done. P0 must remain available on unsupported AR devices. Google official SDK source is Apache-2.0 but AAR binaries have separate ARCore Additional Terms; document the distinction, never claim all binaries Apache. No push, cloud, matching, sheep enablement, schema reset or secret disclosure. This is work in progress, not completion evidence.

**P0 verification in progress:** complete Flutter suite 117 passed (109 previous + 3 field-store/config/backup + 5 offline widget cases), complete Python suite 256 passed (208 backend/tooling + 48 research), Ruff clean. Four-language fresh offline operator/temporary-animal setup at 320x720/200% text passed; six captures/gallery-denial/restart preserves originals, labels, views, keys and strict API metadata. Real bugs found/fixed: ExpansionTile shared PageStorage state with scroll offset; dialog controller disposed before reverse animation finished. Pinned gal 2.3.3 verified local BSD-3-Clause license (not MIT); full text in docs/licenses. Android album API29 permission merge conflict with camera plugin fixed explicitly, no broad READ_MEDIA import permission. APK build initially failed on Gradle DSL java namespace then manifest conflict; repaired and final release build pending, analyzer final run pending. Do not start P1 implementation or call P0 complete until release/signature checks pass and local milestone is committed. Device list still empty; native gallery/airplane behavior is unverified.

**P0 completion evidence (supersedes pending text above):** release build succeeded, final refreshed APK 87.5s, 57.7MiB, SHA-256 f1aa02a1d632c8cbb67fd053f30fb7e84d8f648fc20066de14f584263aeb6c4e; preserved data/artifacts/p0-20261104/app-release.apk. apksigner verifies v2, certificate CN=Android Debug (personal sideload, not production signing); no API_TOKEN define. Every embedded YAML and translation file byte-matches source; Gradle copies authoritative YAML and regenerates hash manifest before Flutter compilation. Existing kotlin.incremental=false retained. Full 117 Flutter/256 Python passed; final provisional-collision guard additionally passed all three field-store tests; Flutter analyzer clean before probe, probe brace-only lint cleanup follows. Real Dart JPEG/QC/queue/restart/ZIP integration produced six distinct synthetic frames and 21-file ZIP: data/offline-p0-20261104/evidence.json. Python independently verified and extracted all21 files into data/restores/offline-p0-20261104. Source originals retained, no server connection/token or real-animal claim. P0 milestone local commit follows; only then start P1. No connected adb device, installation/native album/permissions/airplane remain unverified. Guide docs/OFFLINE_FIELD_GUIDE.md; no push.

**Agrobank accelerator preparation — 2026-10-29 (latest user update):** Sardorbek wants to apply with BioLivestock. He explicitly confirmed he is a solo founder, now has a working phone, and has no animal images yet; he may arrange animal access if useful. Device availability blocker is lifted as a user report, but native end-to-end testing is still unverified; farm partner/access, founder contacts/experience/availability and commercial traction remain unconfirmed. Do not repeat the older broken-phone state as current. Verified official agroventures.uz/accelerator, /application and fund FAQ plus StartupBase announcement: deadline 2026-11-09; published eligibility includes 2–5 founders. Solo eligibility must be clarified rather than invented/waived; organizer-message draft is prepared but not sent. Created docs/AGROBANK_ACCELERATOR_APPLICATION.md with honest UZ/EN descriptions, form-answer draft, 12-week proposed registry/data-quality pilot, measurable non-guaranteed targets, 60-second script, deck outline and internal pre-deadline plan. $25k/six-month budget is an unapproved discussion estimate only, not a submitted ask or purchase authorization; funding/terms/pilot are not guaranteed. Initial practical next steps: clarify solo eligibility, phone smoke test, optional consented 5–10 cattle usability sample (not biometric accuracy), then reviewed application/deck. Full pilot target 100 cattle/three sessions/1,800 usable images remains conditional. No application submission, outreach, offer acceptance, account creation, code/schema change, new build or test run; no push. Entry clean at ffeb288. See new application draft before acting.

**Consolidated handoff prompt — 2026-10-29:** Sardorbek asked for all planned/completed work, decisions, actual stop point and continuation steps in one reusable prompt. Read current root progress, README, roadmap, architecture, registry/security, research/data protocol, weight/spoof, recovery docs and relevant configs/routes. Created docs/PROJECT_HANDOFF_PROMPT.md in Uzbek with complete scope history, file/endpoint map, species/config and permanent-ID invariants, verified-vs-synthetic boundaries, four languages, field protocol, commands, evidence and input-dependent next steps. Entry git clean at 3a960fc; origin correct; cached origin/main counts 0/22, no fetch/push. Flutter launcher still exists; APK SHA-256 recomputed and matches a4012b93d54f4f980680d9c1fcdf58836d7d91f2d41b7dc07a0202dddd966a3f. No application/config/schema/data change, no tests/build/Docker runtime rerun today; 361-test result belongs to 14 October. Phone/dataset availability has no new confirmation. This documentation milestone is committed locally; no push. Continue from the next-action gates below after re-reading live state, not by rebuilding the scaffold or assuming real accuracy.

**Multilingual/code review complete — 2026-10-14 (latest request):** entry clean at c93e34e. Sardorbek requested remaining fixes plus Uzbek Latin, Uzbek Cyrillic, Russian and English. Added 220-message UTF-8 catalogs, persisted Tools language selector (default Uzbek Latin), translated capture/saved/registry/dialog/validation/QC/error/backup UI and render-time notices. Language changes preserve open originals, camera, metadata and request keys; names/notes remain exact Unicode. Species/status API values, MAA/legacy IDs, reference codes, timestamps, hashes and audit evidence keep their formats. Local resources work offline; no new font downloads. Flutter SDK localization plus intl 0.20.3 added/pinned. No sheep activation, model training, schema change, normal-stack deployment or push.

**Direct multilingual verification:** 252 full Python cases passed (204 backend/tooling + 48 research), 109 full Flutter cases passed = 361 distinct cases. Ruff/lint/changed Python format and Flutter analyzer clean. Sixteen locale cases verify all catalog/placeholder/source keys, Unicode/brace preservation, preferences restart/corruption/failed writes/serialization/disposal, actual selector callbacks, HTTP UTF-8 JSON without charset, server QC guidance and four locales at 320x720/200% text. Found/fixed translated heading overflow. Cyrillic SDK adaptation preserves raw application arguments and internal date-order tokens; date/plural/context-menu labels tested. Explicit UiText templates, not arbitrary string translation/transliteration. Phone preferences are versioned/flush-renamed separately from immutable journals; failed saves keep prior language. Backend Unicode owner/note/history/replay cases pass. Final suite has only known upstream TestClient/httpx deprecation; initial restricted temporary-directory run failed permissions, authorized rerun succeeded. No physical device or real checkpoint accuracy claim.

**Runtime/artifact:** rebuilt only isolated biolivestock-reliability on 18001; both services healthy. Source hashes, parallel numbering/idempotency, owner race, synthetic JPEG/QC/pending_model, PostgreSQL row/file/hash and terminal capture link verified (registry-i18n-20261014.json). Four-script Unicode owners/reasons retained in authenticated HTTP, idempotent replay, history and actual PostgreSQL UTF-8 (unicode-20261014.json); all synthetic. Final debug APK built in 50.3s, SHA-256 a4012b93d54f4f980680d9c1fcdf58836d7d91f2d41b7dc07a0202dddd966a3f; all four embedded catalogs byte-match source. Previous builds: 63.3s before final uncached startup fix, and 144.8s before final date/plural changes. No operator token configured. Existing Gradle native-access warning only, Kotlin cross-drive flag/SDK 3.47.5 unchanged. Actual SDK-font four-language widgets rendered/inspected; examples in docs/design/language-*-tools.png are host mocks. Native keyboard/permissions follow OS language; iOS build/native plugins unverified on Windows.

**Recovery / next action:** new data/backups/i18n-20261014 verified and restored into new biolivestock_restore_i18n_20261014 and data/restores/i18n-20261014. Manifest: 65 profiles, 72 animals, 140 audit events, 111 registry receipts, 13 captures/12 upload receipts, one counter; reconciliation healthy, copied file hashes/capture index/table counts verified. Full row comparison/stop evidence recorded at session end below. Previous bundles/clones retained; normal collection data untouched. Detector fix local milestone 9339d2a; multilingual implementation 0895f84; uncached startup guidance 6298ddc; final documentation milestone follows. Requested confirmed code defects and language implementation are complete; don't claim all future phases or absolute reliability. Read docs/LANGUAGES.md. Next: after review rebuild normal backend plus operator-configured phone app per README, then verify language restart, real keyboard names/notes, native capture/GPS, offline queue/registry/history/UUID attachment and backup sharing on a repaired/replacement phone. Phone and real labeled cattle/checkpoint/calibration inputs remain external gates. No routine architecture question pending; no automatic push.

**Final startup review:** without cached rules, the species loader previously replaced the initial authentication/network failure with a misleading no-species error. Retain/rethrow the original error when the cache is empty; a Russian startup widget case proves useful 401 guidance and disabled capture. Cached/offline collection behavior is unchanged. Full Flutter suite now 109 passed (16 locale cases), total 361 distinct tests; final artifact/analyzer refreshed below.

**Detector review milestone:** hash before/after deserialization plus mtime/ctime/size/inode fingerprint reject weights changed during loading (503 retry, no cached mixed provenance). Replace one cached version per checkpoint path instead of retaining all historical models. Eight detector tests passed, including changing-load rejection/recovery and three version replacements/cache reuse/correct digests; Ruff clean. Synthetic mock inference only. Initial sandbox run had temporary-directory permission errors; host-authorized rerun passed with the existing upstream deprecation and inaccessible pytest-cache warning. No live checkpoint installed or normal Docker service changed. Full-suite verification is complete and recorded above.

**Session-end recovery evidence:** i18n-restore-20261014.json verifies complete counter/profile/receipt/animal/audit row contents equal source, including the new Unicode records. Every bundle/restored file hash and capture index/table count checked. Both isolated reliability services stopped with exit 0; volumes, synthetic fixtures and all restore databases retained. Normal collection stack untouched. Final suites/analyzer/APK evidence above is complete; no further code change after final build.

**Previous MVP completion audit complete — 2026-10-14:** Sardorbek asked to finish remaining code; entry clean at 3b18175. Reviewed roadmap, existing QC/detection/auth/storage/provenance, offline queue and registry/mobile logic plus dataset gates. Repaired six concrete gaps: stale animal/slaughter card after failed lookup; torn version/owner/lifecycle reads and N+1 list queries; simultaneous intents from separate phone Journal objects; absent mobile capture UUID attachment; history limited to 50; storage writes following linked directories. Added coherent joined snapshots, shared canonical-directory mutation guard/key/link validation, failed-lookup clearing and manual refresh, optional UUID/hash review with unchanged retries, history paging/failure retention and pre-write symlink/junction containment. No new model, dependency, schema, sheep activation, deployment or push.

**Direct completion checks:** combined Python suite 246 passed (198 backend/tooling + 48 research), full Flutter suite 93 passed = 339 distinct cases. Ruff backend/research/tools and final Flutter analyzer clean. One existing upstream TestClient/httpx deprecation only. Real Windows junction tests verified outside and within-root redirects reject before file creation. Regression tests verify one SQL statement per registry page/detail, authorized matching scan attachment, wrong-animal/unauthorized rejection without version/lifecycle change, cross-instance journal serialization, unsafe acknowledgement keys, stale positive report clearing, capture UUID validation/lost-reply replay and history page 2/failed-page retention. All seven registry widget cases use real SDK fonts. Preview images refreshed/visually inspected; mock renders are not device proof.

**Runtime and recovery:** isolated biolivestock-reliability/18001 verified 200 coherent HTTP reads during 30 committed owner updates with actual overlap (registry-snapshot-20261014.json), plus registry/QC/upload/linked-capture checks. Final rebuild matched all source/config hashes and reverified upload/file/hash/terminal reference (registry-final-storage-20261014.json). Final data/backups/mvp-final-20261014 restored into new biolivestock_restore_mvp_final_20261014 and data/restores/mvp-final-20261014; 51 profiles, 58 animals, 114 audits, 91 registry receipts, 12 captures/11 upload receipts and one counter. All registry/animal/audit row contents matched, every copied file checked and reconciliation healthy (mvp-final-restore-20261014.json). Intermediate mvp-completion backup/clone/evidence retained. Test API/db stopped with exit 0; all volumes/data preserved. The prior numbering test stack stays stopped/intentionally exhausted. Normal collection stack and real animal data untouched.

**Mobile artifact:** final debug APK built in 30.1 seconds after a preceding 34.7-second build, SHA-256 f174e598090052164af0be2746b029b60b56be672fbc9c5f32c3f29cf5669b77. Final brace/style correction passed analyze; no configured operator token. SDK 3.47.5 and kotlin.incremental=false unchanged. Journal guard is shared within the app's UI isolate; backend idempotency/counters remain authoritative across clients. Backup/link guards reduce accidental redirection, not protection against a privileged filesystem/database administrator.

**Exact stop / next action:** defined data-independent MVP/groundwork and all confirmed findings from this pass are complete; local code milestones 5dd1274 (backend/storage) and 8d82675 (mobile); final documentation commit follows. Do not claim every future phase or 100% real-world reliability is finished. See docs/MVP_COMPLETION_2026-10-14.md. Before real new IDs, back up/review then rebuild normal backend/configs together and run the operator-configured app using README. Native phone camera/GPS/keyboard/storage/share/registry/history/attachment remains an external test blocker until repaired/replacement device; no device availability update received. Real reviewed identity sessions/muzzle checkpoint, genuine/attack videos, measured-animal geometry/weights and actual market observations gate production matching/liveness/weight/valuation confidence; sheep data/pilot remain disabled. Existing math, admin price/status/review endpoints and advisory spoof/GPS code are built, not calibrated proof. Corrected stale DATA_REQUIREMENTS statements about authentication and quote implementation. No unresolved routine architecture question or automatic push; resume empirical evaluation when inputs arrive.

## Previous letter-series milestone

**Letter-series implementation complete — 2026-10-14:** Sardorbek authorized implementing the MAA/MAB proposal after the historical discussion below. Config version 3 adds series_letters=2 (cattle M, sheep S still disabled); no schema migration/reset. Shared format maps the existing prefix counter ordinal across 99,999,999-number blocks: AA -> AB and AZ -> BA. An existing counter 20 continues at MAA00000021; existing M IDs, profiles, immutable audit/receipts and capture paths remain unchanged. New IDs are 11 characters and capacity is 67,599,999,324; exhaustion returns 503 rather than wrapping. Both numeric legacy and letter-series namespaces are protected against manual allocation. Entry clean at 2e2bd37; local code milestones 35efa25 (backend) and bba7a96 (mobile); final documentation commit follows. No push or normal-stack deployment.

**Direct series checks:** 194 backend/tooling, 48 research and 88 Flutter tests passed; Ruff/Flutter analyzer clean. Actual isolated PostgreSQL HTTP tests verify eight parallel IDs around each AA/AB and AZ/BA boundary, concurrent same-key replay, final MZZ99999999/503, and a synthetic pending_model upload/file/hash. The dedicated biolivestock-numbering stack on 18002 was fresh/empty before forward-only boundary seeding; do not issue real IDs there. Existing biolivestock-reliability on 18001 successfully continued its old counter under the new format. All 20 old numeric-ID animal/profile rows, 27 audit events, two captures and 24 receipts matched yesterday's restore clone; one old issuance receipt replayed unchanged. Evidence data/numbering/evidence/rollover-20261014.json and data/reliability/evidence/{registry-series,legacy-series}-20261014.json. No normal stack/data touched, no push.

**Recovery and mobile completion directly verified:** updated reliability store backed up to data/backups/series-20261014 and restored to new biolivestock_restore_series_20261014 / data/restores/series-20261014: 30 profiles, 37 animals, 50 audit events, 36 registry receipts, ten captures/nine upload receipts, one counter. Fresh boundary store backed up to data/backups/numbering-20261014 and restored to new biolivestock_restore_numbering_20261014 / data/restores/numbering-20261014: 20 profiles/animals/registry receipts, 21 audit events, one capture/receipt, one counter at 67,599,999,324. All registry/animal/audit contents match their sources, not only counts; manifest image reconciliation healthy. Evidence series-restore-20261014.json and data/numbering/evidence/restore-20261014.json. All four verification containers stopped with exit 0, volumes/fixtures/clones retained. Never issue real IDs from these test stores; boundary store is intentionally exhausted.

**Final verification:** 194 backend + 48 research + 88 Flutter = 330 distinct tests passed; four actual-font registry cases also passed while rendering refreshed MAA previews. Flutter analyze and Ruff backend/tools clean. New client guidance reads numbering config without allocating IDs; old cached configurations/journal receipts still recover, while current Capture/Animals and narrow/200% text accept longer IDs. Final debug APK built in 41.7 seconds; SHA-256 29f37a78c3fe5c094bc1e68e5be988986b4706075da3eaa0013659b415dc0cd8, no API token configured. Registry previews visually inspected and refreshed under docs/design; mock UI rendering is not a phone check. Existing Kotlin cross-drive setting/SDK unchanged.

**Next action:** requested code work is finished. Before collecting real new IDs, back up the normal backend and review/rebuild backend plus mounted config together with docker compose up --build -d from backend/. Schema stays 0005; no extra migration/reset. Rebuild/run the operator-configured phone app using README. Do not roll mixed allocator versions or edit the live numbering format/counter. Physical phone remains unavailable/unverified; confirm capture/GPS, new ID acknowledgement, old ID lookup, offline replay and archive/backup on a repaired/replacement device. Real dataset/checkpoint gates biometric/slaughter/liveness/weight accuracy as before. No architectural question pending, sheep remains disabled, no automatic push.

## Historical numbering discussion and earlier registry milestone

**Numbering discussion — 2026-10-14 (historical, superseded above):** Sardorbek proposed fixed-length MAA + eight digits, advancing MAA -> MAB after 99999999 rather than lengthening numbers. Recommended sequence: MAA00000001 ... MAA99999999, MAB00000001 ... MAZ..., MBA... through MZZ99999999. Two A-Z series letters permit 676 blocks of 99,999,999 usable numbers = 67,599,999,324 IDs, each 11 characters. Existing M+eight-digit IDs must remain unchanged, reserved and resolvable. This turn answers his design question only; automatic letter-series rollover is not implemented or deployed. Live inspection found a clean tree at d256403 and confirmed current YAML/service still use M/eight digits with exhaustion returning 503, not rollover. Any follow-up implementation must explicitly preserve old counters/receipts/IDs and test boundary/concurrent allocation; never implement rollover by resetting a counter or recycling an ID. No database, mobile or numbering config changed; no new tests needed for this discussion/memory-only update. No push.

**Permanent numbering/ownership/lifecycle complete (2026-10-13, latest request).** New cattle register once with server-issued M00000001-style IDs, readable tabular digits and owner reference/name. Mobile now has Capture/Saved/Animals/Tools; Animals supports owner transfers, death/slaughter reports, active/archive lists and abattoir ID/report/history lookup. Clarification: Sardorbek meant death, not sale; no sale terminal state. Death/slaughter archives rather than physically deletes; IDs, owners at reporting, scans and immutable history remain. Additive migration 0005 preserves legacy IDs/data. New IDs require one canonical backend; existing registered IDs still collect offline. Entry clean at 9c745b1. Local code milestones: b9a34a4 (backend) and 9f577a4 (mobile/recovery); final documentation commit contains this update. No push or normal-stack deployment.

**Key decisions & config:** cattle numbering M/eight digits in species_configs/cattle.yaml, sheep S/eight digits present but disabled. No sheep models/branches added. Never reset counters/change live numbering format or issue real IDs from independently writable test/restore clones. Stale backup restores after later issued IDs need reconciliation before writes. Financial open/insured/collateral status remains separate (also labeled Financial in UI); death/slaughter does not automatically settle it. Original registrar/admin controls owner/terminal changes; owner references are ledger identities, not accounts, consent/legal ownership proof. Server and mobile retain replay keys/immutable payloads; acknowledgement loss/restart cannot silently allocate another ID. Pending/corrupt/rejected journals remain backed up; new number remains visible until acknowledged. Full owner/time/GPS/report metadata is sensitive; protect backup copies. New numbering prevents collisions, not multiple IDs for the same physical animal; independent tag/session checks remain necessary.

**Abattoir boundaries:** lookup says registry record only and explicitly false for independent slaughter/biometric verification. Actor/server receipt time plus operator-reported time/GPS are audited; GPS may be null and is not trusted location proof. Optional API capture_id attaches a matching authorized scan/hash; the mobile report form currently records notes/facility/time/GPS without a capture attachment picker. Terminal reports cannot be edited/reactivated; no fake positive identity/liveness verdict. Delayed captures of an existing archived ID retain evidence without reactivation; the registry selector offers active captures only. No real image/model accuracy claimed.

**Backend registry milestone directly verified:** 171 backend/tooling tests passed; Ruff clean. Migration 0005 preserves legacy registrations/scans and adds three tables with append-only receipts, retained identities and forward-only counter guards. Isolated biolivestock-reliability on port 18001 applied migration and matched all current backend/config hashes. Eight concurrent requests allocated distinct M IDs; four simultaneous retries returned one ID/receipt; competing owner transfers returned 200/409. Numbered JPEG upload passed QC with pending_model, stored file/hash and immutable terminal capture reference. Archive replay/authentication/sheep-disabled/SQL trigger checks passed. Evidence data/reliability/evidence/registry-20261013.json. Test probe ran twice: first harness stopped on a correctly rejected SQL guard; both synthetic fixtures retained, no normal data touched.

**Recovery verified:** data/backups/registry-20261013 restored into new biolivestock_restore_registry_20261013 and data/restores/registry-20261013. All counter/profile/receipt/animal/audit contents match source (registry-restore-20261013.json), not just counts. Source/clone: 20 profiles, 24 registry receipts, 27 animals, 35 audit events, nine captures/eight upload receipts; reconciliation healthy with no missing/mismatched/orphan files. Both test containers stopped with exit 0; volumes, clones and evidence retained. See docs/ANIMAL_REGISTRY.md.

**Mobile directly verified:** full 84 Flutter host tests passed, plus four final real-font widget cases after clarifying Financial status; analyzer clean. Nine new journal cases cover lost reply/restart, explicit ID acknowledgement, receipt-write failure, changed payload, backend/operator scopes, known rejection, malformed acknowledgement, corruption and backup inclusion. Two HTTP contract tests and four registry widget scenarios cover issuance/recovery, owner/slaughter validation, death retry and stale-version cancellation, archived controls and 320x720 at 200% text. Integrated Capture/Animals navigation cannot relabel an open original and returns to it with visible feedback. Actual native widgets rendered with SDK fonts and mock boundaries, visually inspected; previews docs/design/registry-*.png plus refreshed capture/saved/tools. New ID and registry dialogs have no gallery/photo source substitution. Full totals: 171 backend + 48 research + 84 Flutter = 303 distinct tests. Backend suite has dependency deprecation and inaccessible pytest-cache warnings only; no failed tests. Final Android debug APK built in 26.1 seconds (preceding build 45.2 seconds), SHA-256 998d45179dada676d1dc1eca2313a38ae25cc108654899fb0ee58e25e488191e. No API token configured in this build. SDK C:\src\flutter (3.47.5), kotlin.incremental=false unchanged.

**Exact next action / external blockers:** before new real numbering, back up the normal backend, review then rebuild from backend/ with docker compose up --build -d (startup applies 0005). Rebuild/run the operator-configured app using README. On a repaired/replacement phone verify native camera/GPS/keyboard and registry creation/acknowledgement, offline restart/retry, owner changes, death/slaughter archive lookup and ZIP export/share on synthetic test records. Real phone remains unavailable/unverified; this is external, not a known code blocker. Real cattle dataset/checkpoint/calibration still gates biometric matching, actual slaughter/identity authenticity, liveness and weight accuracy. Guide now maps server IDs to separate farm cohort slots; preserve all existing labels. No routine architectural question is pending. Requested code work finished; no automatic push or new model work.


## Git evidence — multilingual code milestones, before final documentation commit

Live inspection: 2026-10-14. HEAD 6298ddc. Pending changes are requested README/docs/previews only; final documentation commit follows. Cached origin/main remote-only/local-only counts: 0/21; no fresh fetch or push. Inspect live status/log next session.

Real git log --oneline -20:

```text
6298ddc Preserve authentication guidance when capture settings have no offline cache
0895f84 Add persisted Uzbek Latin and Cyrillic, Russian and English mobile UI
9339d2a Keep detector checkpoint provenance consistent and bound replacement cache
c93e34e Record completed MVP audit, recovery evidence and remaining field data gates
8d82675 Complete registry lookup, evidence attachment, history paging and phone journal guards
5dd1274 Read coherent registry snapshots and prevent redirected capture writes
3b18175 Document series rollover, legacy compatibility and verified recovery
bba7a96 Display series IDs and preserve legacy mobile journals and cached rules
35efa25 Allocate fixed-width animal letter series without resetting legacy counters
2e2bd37 Record fixed-length letter series numbering proposal and current limits
d256403 Document permanent IDs, field ownership reports and verified registry recovery
9f577a4 Add mobile animal registry, durable ID acknowledgement and archive workflows
b9a34a4 Add permanent species-configured animal numbers and audited ownership lifecycle
9c745b1 Document mobile design references, visual previews and verification
7b86d1c Redesign field capture, saved originals and backup tools for mobile
5c16b0c Refresh persistent progress with final runtime and git evidence
1a511e4 Document verified collection enhancements and field recovery limits
b6c4e0b Pin tested backend containers, CPU dependencies and Flutter SDK
001b9a2 Respect Windows path casing when exporting phone evidence
183341b Export verified phone evidence and scale restart-safe capture queues
```

Real git remote -v:

```text
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

## Previous mobile design milestone

**Mobile design refresh complete (2026-10-13, latest milestone).** Sardorbek authorized the app redesign; entry clean at 5c16b0c. Native Flutter now has a shared forest/ivory/Roboto design system and separate Capture, Saved and Tools navigation. Camera and fixed capture/review actions stay prominent; animal fields, QC/GPS feedback, pending originals, receipt cards, backup and settings have consistent surfaces. Error notices use icon/text/red feedback; guidance overlays remain readable on bright camera backgrounds. No new dependency, backend/research change, authentication change, schema/model work, sheep enablement or push.

**Verified directly:** all 68 Flutter host tests passed and final analyze was clean. Existing eight camera/GPS/lifecycle/restart/storage/export/partial-batch/pagination cases remain; new tests cover 320x720 at 200% text, visible invalid-ID feedback without capture, failed upload with retained original and successful receipt review, QC retake and Android touch-target guidance on Capture/Tools. Actual Flutter widgets were rendered with SDK Roboto/Material fonts and visually inspected. Seven mock/synthetic frames in data/design/20261013; three representative frames are committed under docs/design for review. They are not physical camera screenshots or real animal images. Final debug APK built in 26.0 seconds; SHA-256 9850861814a9972ecb96938732f3e4b46429763f47d25d979dd66f12e4eafcc1. No API token configured in that APK. Backend/research tests were not rerun because those sources did not change.

**Decisions to preserve:** use native widgets/system typography, no runtime font downloads or third-party brand assets. Public Herdwatch, Datamars Active Tag and CattleEye pages/image references informed the design; browser automation failed initialization, so no authenticated competitor-app walkthrough is claimed. Design/links/repeat checks: docs/MOBILE_DESIGN.md. Capture/tools use eager scrolling forms so off-screen validation remains mounted; Saved retains the existing 50-item pagination. Labels describe local/cached-rule state rather than inventing network connectivity. Guide boxes are positioning aids, not detections/crops/identity/liveness. QC metrics and immutable timestamp/request/receipt details remain reviewable; originals and metadata semantics are preserved. English UI retained.

**Local design milestone:** 7b86d1c contains the tested native UI and progress update; documentation/previews follow.

**Exact stop / next action:** design implementation and host verification are finished; commits local only. Test the new APK on a repaired/replacement device with README operator configuration: native preview/orientation, camera/GPS permissions, real keyboard, text scaling, offline restart/upload, receipt review and backup/share; also judge daylight/gloved usability. Phone availability and real animal/model/calibration data are still external blockers. No normal Docker stack, collection data or queue format was changed. One verification approval review timed out, then its explicitly permitted retry succeeded; no unresolved approval block.

## Collection enhancements — preceding 2026-10-13 milestone

**All five requested collection enhancements are implemented and verified (2026-10-13).** Phone ZIP export/recovery, measured 1,800+ queue performance with 50-item pagination, mocked CaptureScreen scenarios, dependency/container pins, and exact decoded-pixel research duplicate checks are complete. Entry eaaf857 was clean. Local-only milestones: fff4799 (research), 183341b (phone export/scale/screen tests), 001b9a2 (Windows path guard); b6c4e0b (tested dependency/container pins), 1a511e4 (final evidence and recovery documentation). No new GitHub push is authorized. No new models, sheep logic, paid services or schema changes.

**Direct checks:** 161 distinct backend/tooling cases passed (157-suite plus four added archive-security guards; all 10 backup tests passed), 48 research and 64 Flutter host tests passed: 273 total. Python Ruff and Flutter analyze passed; the final Windows case-insensitive export containment regression passed. Final Android debug APK built in 73.2 seconds after the first share-plugin build took 417.3 seconds; SHA-256 8d016a2caf30ef612c7be228dd7c120e8bb470473738b0c6925ae123e1d703d0. No API token configured in the APK. No physical camera/GPS/share-sheet verification.

**Scale and recovery proof:** 1,800 synthetic 64 KiB originals plus journals exported as a verified 3,600-file ZIP. Python independently verified and extracted the Dart ZIP into new data/restores/phone-queue-20261013. Queue warm median fell from 2,110 to 1,052 ms, cold 2,924 to 1,556 ms. Peak process RSS increased; do not claim memory reduction or phone speed. Compiled-host ZIP export: 119,642,784 bytes, 29,081 ms, peak RSS 140,767,232 bytes. Raw measurements: data/benchmarks/*-20261013 and export-verification-20261013.json. Source data and backups retained.

**Pinned runtime proof:** isolated biolivestock-reliability stack on 18001 built successfully; both services healthy, pip check passed, all 63 Python and 40 apt pins plus image identity matched (data/reliability/evidence/runtime-pins-20261013.json). Only opencv-python installed, cv2 5.0.0 and torch 2.14.1+cpu imported. All 47 runtime source/config hashes matched. JPEG upload UUID 2d0d8a0a-3850-4dc9-b27e-d87203d4b380 passed server QC, persisted file/metadata with pending_model and rejected blur/invalid GPS without extra rows/files. Four concurrent retries created one capture/receipt and passed later replay plus 401/403/409 checks: idempotency-pins-20261013.json. Read-only reconciliation healthy: reconcile-pins-20261013.json. Normal collection stack/data untouched. Both isolated test services are stopped (verified); volumes and all evidence retained. Reconciliation covered 7 captures with no missing, mismatched, unsafe or orphan files.

**Decisions/config to preserve:** backup is all local operators/backends, original/journal/receipt evidence including corruption/orphans/partial files; tokens/settings excluded. User must save the ZIP outside the app via the share sheet; temporary app exports are not a second durable copy. Never overwrite an export or live recovery destination. Extraction is evidence-only, not auto upload/relabel/phone reimport. Queue reads use bounded 32-file concurrency and a fresh inventory, no persistent metadata cache; pending/receipt views paginate 50 records. Exact decoded oriented RGB reuse is rejected in reviewed datasets but this is not near-duplicate or biometric matching. Docker pins base digests, apt versions and complete Linux/CPU dependencies; direct Python/dev/pub dependencies are pinned too. Flutter 3.47.5/Dart 3.13.4 and kotlin.incremental=false remain. Missing upstream pinned artifacts fail rather than upgrade; builds are not claimed bit-for-bit deterministic. Details: docs/COLLECTION_IMPROVEMENTS_2026-10-13.md.

**Next action / genuine blockers:** code work requested in this milestone is done. On a repaired/replacement phone, use README operator configuration and prove native camera/permissions/GPS, offline restart and upload, then export/share a ZIP with realistic photo sizes and verify it on the computer before a farm visit. Phone availability remains external/indefinite; host mocks do not resolve it. Real detector/matching, liveness and weight calibration still need reviewed animal/session/measurement data. Continue collection per DATA_COLLECTION_GUIDE.md; sheep stays disabled and no muzzle checkpoint exists, so accepted originals remain pending_model. No routine architectural question needs Sardorbek now. Rebuild the normal backend after review; do not deploy to it or push automatically.

## Published audit repairs — earlier 2026-10-13 milestone

**GitHub publication verified (2026-10-13).** Sardorbek explicitly authorized pushing in this session, superseding the earlier hold for these commits. Fetched origin first: remote-only/local-only counts were 0/20, with no uncommitted work or tracked local secret/data/build files. Normal `git push origin main` advanced origin/main from f2b8698 to b5da129b50233eca536f25227f67b30a3886a8a4; `git ls-remote origin refs/heads/main` returned that exact SHA. This progress/README publication-status commit follows the application revision. No force push. Future pushes still require an explicit user request; do not interpret this one publication as a recurring autopush mandate.

**All eight confirmed audit defects are implemented and verified (2026-10-13).** Sardorbek asked to fix the complete audit. See docs/AUDIT_REPAIRS_2026-10-13.md for the repair mapping, evidence and repeat commands. Local milestones: d3704e5 (F1 commit evidence), 4ac39d8 (F3 complete restore checks), 8c722c2 (F5/F6/F8 validation), de5e76d (F2/F7 journal/ID), 0ba8dd7 (F4 exposure), followed by b5da129 (verification/documentation). These milestones were subsequently published as recorded above. No breaking schema change or normal-stack deployment; existing collection data was preserved.

**Repair checks (before collection enhancements):** 151 backend/tooling + 46 research + 53 Flutter host tests passed (250 total); Ruff and Flutter analyze passed. Android debug APK built successfully in 294 seconds; SHA-256 4f339a1cdcaaba5fb735a2c8cb5880aabbb3438557f84b0d27413556cc38045c. No API token configured in that APK. SDK remains C:\src\flutter and kotlin.incremental=false. No physical-camera/GPS/plugin test was performed.

**Repair runtime proof:** isolated biolivestock-reliability stack on port 18001 was healthy; all 47 backend/migration/config hashes matched source (data/reliability/evidence/source-hashes-20261013.json). A real PostgreSQL commit followed by injected driver acknowledgement failure retained the original and replayed capture 2cffb976-5575-44b2-969b-502c4c6ccb1f; evidence commit-recovery-20261013.json. Four concurrent authenticated retries created one capture/receipt, with changed-payload 409 and auth/operator checks (idempotency-20261013.json). Actual Dart local QC/filesystem/HTTP simulated response loss, reopened the queue and replayed UUID 3b4ae812-b25c-4538-89a7-0d2a554efeec; journal/receipt directory data/reliability/mobile-queue-20261013. These are synthetic checks, not actual network outage or animal accuracy evidence.

**Repair recovery proof:** backup data/backups/reliability-repairs-20261013 restored to new biolivestock_restore_repairs_20261013 and data/restores/reliability-repairs-20261013. Source/clone each have 5 captures, 5 receipts, 5 animals, 5 audit events; revision 0004; no market/duplicate rows. Every copied file matched its manifest hash, including explicitly synthetic research labels/JPEG, and capture index/table counts agreed. Reconciliation healthy: data/reliability/evidence/reconcile-repairs-20261013.json. Both test containers are stopped; all volumes, clones, files and evidence retained. Normal stack/data were not deployed to or modified. During intermediate edits an old image rejected newly mounted geometry config; rebuilding completed source resolved that mismatch before final checks.

**Decisions to preserve:** after COMMIT is attempted, never delete uncertain image evidence; replay checks original hash/crop existence and returns 503 for unavailable/changed evidence. Pre-commit SQL/write failures still clean up new files. File fsync precedes COMMIT; Linux also fsyncs directory entries. A true rollback at the uncertain boundary may leave retained orphans for reconciliation. Typed version-1 journals isolate bad files, preserve original labels/keys/timezone offsets and expose issues; healthy items remain usable. Both exposure histograms use original oriented pixels, with only blur resized; no QC thresholds changed. Chest contours are validated as planar/simple without reordering or hull substitution; per-species engineering tolerances are 1% relative planarity and 1e-6 geometry epsilon, not animal calibration. SafeTimestamp rejects UTC overflow for capture/GPS/price observations. Research imports fully decode pixels before accepting crops. Sheep stays disabled, no muzzle checkpoint exists, accepted originals remain pending_model.

**Next action:** after review, rebuild the normal backend from backend/ with docker compose up -d --build, and rebuild/run the operator-configured app using README instructions. Preserve app data so existing valid version-1 journals recover. On a working phone verify real camera/permissions/location, offline capture/restart, recovered metadata and authenticated upload before a farm visit. Phone availability has not been re-established. Continue field collection/manual crop and identity/session review per DATA_COLLECTION_GUIDE.md; real detector/matching, video liveness and measured-weight calibration remain blocked on empirical data. The eight confirmed repairs are complete. Those optional collection enhancements were subsequently implemented; see the current milestone above. This historical repair summary does not claim that every conceivable code task is exhausted.

**Audit history:** original audit commit 27c1e85 analyzed d99c2f1, reproduced one P1/six P2/one P3 and made no application edits. Its diagnostic scripts under docs/audits/2026-10-13/ describe the old failure behavior and can stop early now that invalid input is rejected; use regression tests for current acceptance. Initial sandbox tests had temp/SDK access failures; authorized reruns passed. Original source audit and repair plan remain in docs/CODE_AUDIT_2026-10-13.md; current status is the linked repair follow-up.

## Collection-reliability milestone — 2026-10-08 history

**All four authorized collection-reliability improvements are complete (2026-10-08).** Durable offline phone capture, authenticated idempotent uploads, reviewed CSV-to-manifest import and verified backup/isolated restore/read-only reconciliation are built and tested. Local milestone commits: e9b9642 (upload receipts), dba3ee6 (CSV importer), c566a2c (backup/recovery), followed by the final mobile/reliability commit containing this update. No push and no new embedding/matching or sheep-specific model work.

**Verified this session:** 122 backend/tooling tests + 45 research tests passed, Ruff passed, Flutter analysis had no issues and 17 Flutter host tests passed. The README's backend-directory pytest command also passed (pythonpath includes the repository for tooling tests). Final Android debug APK built in 49.6 seconds; SHA-256 b8738369d54de1321f37d8f07b994f3ff22e529436d91144a9d5a7d0b672f1f4. First build took 498.8 seconds while Gradle installed required Android SDK Platform 35/CMake 3.22.1 using existing accepted licenses. Flutter itself was not upgraded; C:\src\flutter and kotlin.incremental=false remain. This APK has no configured API token; use the README's operator-configured flutter run command.

**Direct runtime proof:** isolated Docker/PostgreSQL stack biolivestock-reliability on 18001 passed four simultaneous same-key retries (one capture/receipt), exact response replay, changed-payload 409 and auth checks. Evidence: data/reliability/evidence/idempotency-20261008.json. Actual Dart local QC/queue/filesystem/HTTP integration simulated losing the response after server persistence, reopened the queue and returned the same UUID on retry: bb8f1414-122b-49c9-9f52-1ba1767bc046. Local original/journal/receipt retained in data/reliability/mobile-queue-20261008. All 46 runtime backend/config hashes matched source. These are synthetic/host integration checks, not physical camera or real-animal accuracy proof.

**Recovery proof:** final backup data/backups/reliability-final-20261008 verified every included file, copied all database tables and restored exact table counts/capture index into new biolivestock_restore_final_20261008 plus data/restores/reliability-final-20261008. Source/clone each had 2 synthetic captures and 2 receipts. Read-only reconciliation was healthy: data/reliability/evidence/reconcile-final-20261008.json. Earlier backup/clone also remain. The tool validates the API's actual storage bind mount, briefly stops/restarts only that API for a consistent snapshot, and never overwrites a database/directory or deletes orphan data. Missing legacy/crop hashes are explicitly unavailable. Isolated containers are stopped after verification; volumes/images/backups/evidence retained. No normal stack was running at entry; normal collection data/volumes were not changed or deployed to. Rebuild/start the normal backend before using the new app (migration 0004).

**Persisted decisions:** passed local QC commits an original plus immutable labels/time/GPS to app-support storage before Saved on this phone; Next capture retains it, restart recovers it, and originals/receipts remain after upload. No secret tokens in journals/settings. One online connection caches enabled species/QC settings; later capture can be offline. Upload is manual; batch stops on first error, individual pending items can still be reviewed/uploaded. Entries stay bound to their original backend/operator; conflicts/corruption are retained for review. The app refuses to POST to a backend without idempotency capability. Server QC remains authoritative; offline passes are provisional. Additive migration 0004 receipts are operator-scoped, atomic with capture, replay the original response, reject changed payload, and have no expiry; older keyless clients retain old behavior. CSV import never infers animal/session identities or fabricates reviewed crops. Sheep stays disabled; no muzzle checkpoint exists, so accepted originals remain pending_model with null crop.

**Next action / limits:** Sardorbek reports collecting photos. Apply docs/DATA_COLLECTION_GUIDE.md and use tools/research.py import-csv only after manual crop review and independent animal/session ground truth. Session/farm/camera/tag/view/request-key remain ledger fields; do not put unknown fields into upload JSON. Mobile receipts map request keys to server UUIDs. Keep phone free space and never clear/uninstall its only-copy queue; keep credentials/models separately protected from backup bundles. On a working phone, verify capture while offline, app close/reopen, recovered labels and authenticated upload before a farm visit. Physical runtime remains unverified here (last phone report was water damage; collecting photos does not establish this app's runtime). Labeled-data calibration/training, genuine/attack video reliability and measured-animal weight accuracy remain blocked on empirical data. The requested four improvements are finished; do not invent further model work while waiting. Setup/recovery: docs/COLLECTION_RELIABILITY.md; latest checks: docs/VALIDATION.md.

## Live Git evidence from the D: project

Checked live after the UI milestone at 7b86d1c, before the final design documentation/previews commit. The remaining changes were only design/README/validation documentation and three synthetic UI PNGs. No fetch or push in this design task; origin/main remains the previously verified publication, not a new live remote comparison. The final documentation commit follows this snapshot; refresh status/log on next entry.

```text
7b86d1c Redesign field capture, saved originals and backup tools for mobile
5c16b0c Refresh persistent progress with final runtime and git evidence
1a511e4 Document verified collection enhancements and field recovery limits
b6c4e0b Pin tested backend containers, CPU dependencies and Flutter SDK
001b9a2 Respect Windows path casing when exporting phone evidence
183341b Export verified phone evidence and scale restart-safe capture queues
fff4799 Reject exact decoded-pixel duplicates in reviewed research datasets
eaaf857 Clarify published repair milestone status
ad5f754 Record authorized GitHub publication of audit repairs
b5da129 Record verified audit repairs and PostgreSQL recovery proof
0ba8dd7 Measure mobile exposure before resizing and share clipping regression fixtures
de5e76d Isolate corrupt offline journals and validate capture labels before saving
8c722c2 Reject invalid contour geometry, truncated research pixels and unsafe UTC times
4ac39d8 Verify every restored image and research file against backup hashes
d3704e5 Preserve capture evidence across uncertain database commits
27c1e85 Document code audit findings and reproducible repair plan
d99c2f1 Persist camera captures offline with restart-safe upload retries
c566a2c Add verified collection backups and isolated restore drills
dba3ee6 Import reviewed crop annotations into validated research manifests
e9b9642 Make authenticated capture retries idempotent across API workers
```

```text
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (fetch)
origin	https://github.com/sabdur4hmonov/animal.id.creator.git (push)
```

## Earlier implementation and verification (2026-10-01 history)

- Backend source contains FastAPI health/species/capture endpoints, OpenCV blur/lighting checks, SQLAlchemy metadata, Alembic migration, local image storage, and Docker Compose with PostgreSQL. **51 backend tests passed and Ruff passed on 2026-10-01.** Tests use temporary SQLite and synthetic images/model doubles; they do not establish PostgreSQL runtime integration or real model accuracy.
- **Docker/PostgreSQL verified by the agent on 2026-10-01:** built latest source in a separate `biolivestock-verification` stack on port 18000; uploaded a real cattle-nose JPEG; confirmed passed QC, HTTP 201, saved normalized JPEG, matching host/container SHA-256, PostgreSQL metadata/config snapshot and `pending_model` with null crop/detection. Blurry image and NaN GPS requests returned 422 without extra files/records. Normal containers were already healthy at inspection, consistent with Sardorbek's earlier visual report.
- Flutter camera source now includes bearer authentication, principal-bound operator label, Android device heuristics and mock-GPS evidence. Static analysis, host tests and Android debug APK build passed. Actual launch/camera/permissions/location/upload on a device remain unverified; phone availability is the blocker.
- YOLO wrapper and species-aware configuration are present, but there is **no cattle muzzle checkpoint** and no real inference verified. Quality-approved original images therefore use crop_status=pending_model and crop_path=null. Do not fabricate a crop.
- Cattle is enabled and sheep disabled. Both use the same species schema and YAML pattern for model path, crop parameters, and quality thresholds. Adding sheep later should use its config/model rather than separate processing branches. The Phase 1–5 scope is in docs/ROADMAP.md.
- Offline Phase 2 source is implemented under research/, separate from the capture API. Checksum-verified frozen ResNet18 extraction, normalized embeddings, exact cosine matching and error-rate reporting are executable. No cattle-specific trained model, production identity endpoint, calibrated acceptance threshold, or vector service is claimed. Sheep's research config is disabled and no sheep weights were downloaded.
- A separate recovery bundle and staged initial commit 6dda7a5182f2f83cc2d8445221df7263ed58098f exist under the Codex outputs/work area. That commit is **not in the live D: repository**, whose initial commit is f2b8698. Do not import the bundle over current work.

## Key Decisions & Config

- **2026-11-04 offline/AR:** cattle business config **v2**, AR settings optional for legacy config compatibility; sheep remains unchanged/disabled. Fast girth is `ramanujan_ellipse_ii` (uncalibrated depth/width ellipse); contour is `ordered_closed_contour`, with AR metric provenance separate from the legacy physical-reference calibrated_3d API. Neither detailed-mode naming nor geometric validity guarantees animal accuracy. Never mix mode/breed/species/config hash/formula calibration groups. Config gates: 2–3 repeats, max 5% relative difference, 8–128 contour points, confidence≥0.8, raw depth/point-cloud age≤100ms, depth/hit agreement and anchor drift≤3cm, ≤180s per run, 10–500cm segments, optional scale-check error≤5%. These are engineering gates, not calibrated performance claims. All tolerances/coefficient inputs are per-species YAML; source bytes copied/hashed into APK at build.
- **Correction:** median actual/uncorrected ratios using the latest eligible weighing revision per distinct local animal label, minimum N=10 from YAML; scale date within 7 days of AR set, no future dates. Duplicate labels for the same physical animal would invalidate the statistical assumption; operator identity checks are still necessary. Coefficients are versioned immutable snapshots with N, sample keys, MAPE before/after and explicitly **in-sample** evaluation. N below threshold never applies correction. User on/off choice is appended and restored with its eligible set/config; new weighing/recalculation disables the current choice until explicitly enabled. Both uncorrected/corrected outputs remain visible. No automatic syncing/relabeling or permanent MAA issuance offline.
- **Native/rendering license:** pinned official `com.google.ar:core:1.54.0` works with the existing toolchain; chose a small original Kotlin/OpenGL renderer/platform channel instead of an uncertain Flutter AR plugin or unlicensed GitHub helper. Checked Google official v1.54.0 LICENSE and hello_ar_kotlin source; sample source is **Apache-2.0**, prebuilt runtime AAR/binaries carry **separate ARCore Additional Terms**. See root NOTICE/README for exact sources/URLs. No sample helper/asset/unlicensed renderer copied, no Cloud/Geospatial service or external inference. Do not claim the binary is Apache-licensed. Native results use an internal temporary file instead of carrying JPEGs across Android Binder's size limit. `kotlin.incremental=false` remains unchanged for the D:/C: cross-drive Kotlin issue.

- Anti-spoof signals are advisory review flags: Fourier periodic energy, connected specular highlights, quadrilateral boundaries, Android root/emulator hints and client/native mock-location/time/accuracy/speed checks. They never return a live/genuine verdict or reject as proven spoof; client claims are untrusted. security_configs/ preserves the same per-species schema; sheep remains disabled. Motion/breathing is explicitly blocked on labeled animal videos. Synthetic wave/white rectangle/random controls prove computation only, not photographed-screen or cattle attack accuracy. SDK is actually available at C:\src\flutter; do not resume an obsolete SDK-install blocker. Flutter host/static checks passed; device behavior remains externally blocked.

- Formula/valuation choice: canonical Trukhanovsky (user's “Truxanov”) adult-cattle girth×straight length×factor/100 (dairy 2, beef 2.5) and Schoorl (girth+22)²/100 kg convention. business_configs/ holds parameters; disabled sheep only has requested 45–52% yield placeholders, no sheep formulas/model logic. Cattle yield 50–58% is a scenario assumption, not boneless-meat yield/confidence. Inputs are tape/stick cm or explicitly calibrated 3D closed chest contour, never inferred girth from side-view pixels. Real-world accuracy remains false. Prices start unset: admin-only append-only carcass quotes require currency, source, observation time and expected_latest_id, with stale-edit protection. No financial contract/automatic loan decision or market feed is claimed.

- Latest security/registry additions: hashed local operator/admin keys, fail-closed API dependencies, upload operator binding, separate mutable animal status and append-only scan/audit evidence, exact-pixel reuse review without biometric claims. Status is an admin assertion, not a legal/financial certificate. New scan receipt time and byte/pixel/stored-JPEG hashes are captured; GPS/capture timestamp remain immutable device assertions, not verified location/time. Legacy new provenance fields stay null. Migration 0002 is additive and backfills existing collection labels as open. See docs/SECURITY_AND_REGISTRY.md; dev mobile API_TOKEN is extractable from the binary and is not a production device credential solution.

- Phase 1 has no YOLO checkpoint. Preserve quality-approved originals with crop_status=pending_model and crop_path=null; do not fabricate a muzzle crop.
- Species configuration is YAML-driven: cattle enabled, sheep disabled, with per-species model and crop parameters.
- Server QC is authoritative. Exposure histograms use original decoded grayscale pixels; only blur analysis is resized. Since 2026-10-13 mobile exposure also uses original pixels; decoder/blur approximation differences remain possible. No thresholds were changed without farm-image calibration.
- Species configuration rejects NaN/infinite numbers at validation time. Metadata errors omit raw input values so invalid GPS values still receive a serializable HTTP 422 response.
- Offline research reuses the Species enum but keeps feature model/preprocessing configs in research/species_configs/, avoiding changes to collection/mobile contracts. Cattle baseline: ImageNet ResNet18 avgpool, 512 dimensions, padded full muzzle, L2 normalization. Use exact cosine only as an evaluation reference; production vector-search selection awaits measured accuracy/latency and operational targets. Threshold arguments are research inputs, not accepted product policy.
- Reviewed dataset manifests enforce image hashes, distinct animals across train/validation/test, distinct same-animal gallery/query sessions, and no duplicate content. Unknown queries are outside gallery identities. Checkpoint hashing, NumPy allow_pickle=False, and exclusive output creation protect experiment provenance/evidence. Official baseline weights are under ignored models/cattle/research/ (.pth is ignored), distinct from the absent YOLO muzzle checkpoint. Torch is available in Docker, not the Windows .venv; do not install a second heavy runtime merely to run research.
- Existing mobile test setup uses a physical Android phone over USB; no emulator is configured. Do not create an emulator as a substitute without a new user request. Backend work proceeds independently while the phone is unavailable.
- **Windows cross-drive Kotlin build:** D: project with C: Pub/Gradle caches previously crashed with “this and base files have different roots.” Keep `kotlin.incremental=false` in mobile/android/gradle.properties. This supported JVM compilation switch trades incremental speed for cross-drive portability; moving caches would be machine-specific. Sources: https://kotlinlang.org/docs/gradle-compilation-and-caches.html and https://github.com/flutter/flutter/issues/187658. Verified successful on 2026-10-01 with Flutter 3.47.5 / Dart 3.13.4 / Gradle 9.3.1. Do not re-diagnose or undo the flag without a verified upstream fix.

## Settled decisions and next check

Phase 1 collects cattle camera images and structured metadata. The latest mandate authorizes later roadmap phases where data/device prerequisites permit; do not build sheep models/crop branches, push, spend money, or use external credentials without approval. Server QC is authoritative; mobile QC is advisory. GPS can be null. Animal IDs are operator-supplied labels. Uploads remain manually initiated; since 2026-10-08, requests with an operator-scoped idempotency key replay the committed response, while legacy keyless uploads do not. The 2026-10-13 repair preserves uncertain commit evidence and checks retained files before successful replay. Research results must not be treated as validated identity/liveness/weight evidence.

Backend upload verification is complete. The separate project volume and `data/verification` keep samples apart from normal collection. Capture/evidence UUID: `24510aa3-f88a-43d8-aeeb-46efa72e4d19`. Evidence JSON: `data/verification/evidence/24510aa3-f88a-43d8-aeeb-46efa72e4d19.json`. HTTP 201/QC score 0.8008, 2816×2120 JPEG, matching host/container hash, PostgreSQL pending_model row; blurry/NaN requests 422 with no extra persistence. Samples/evidence and the database volume are retained. Verification containers were stopped after testing to free resources. Reproducible script: tools/verify_docker_upload.py; commands/attribution: docs/VALIDATION.md and docs/SAMPLE_MEDIA.md. Optional API_PORT/STORAGE_DIRECTORY support isolation; defaults remain 8000/data. The normal backend was subsequently rebuilt, returned HTTP 200 database ok, and its source hashes matched current backend code; normal collection data/volumes were preserved.

Resume physical mobile testing only when a repaired/replacement device is available. Discover its actual ID, not automatically 23117RA68G. From mobile/, run flutter pub get, adb -s <device-id> reverse tcp:8000 tcp:8000, then flutter run with API_BASE_URL=http://127.0.0.1:8000 plus OPERATOR_ID/API_TOKEN from the ignored operator credential file (exact PowerShell command in README). Never embed the admin key. Run flutter clean only if rebuilding stale artifacts; a fresh debug build already passed. Verify camera/permissions, real location/mock flag, QC/retake, authenticated upload, provenance/pending_model and admin review. The fallback 10.0.2.2 is for emulators; no emulator was configured.

## Backend hardening completed — 2026-10-01

- Reproduced two clipping regressions, six non-finite GPS error-response failures, and an accepted infinite blur threshold before fixing them. Lighting now counts original pixels rather than resized averages; API metadata rejection no longer echoes invalid raw numbers; species config requires finite numeric values.
- Added rejection-path assertions for malformed metadata, no/multiple detected muzzles, unavailable models and poor crops; confirmed no image or capture row is created. Added partial crop-write failure cleanup, database health failure, nullable GPS/UTC storage dates, EXIF orientation, BGR decoding, unsupported/truncated image rejection, and Alembic upgrade/schema comparison/downgrade tests.
- Baseline: 25 tests passed. Final: **51 passed**, using `..\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider` from backend/. Ruff: `..\.venv\Scripts\python.exe -m ruff check . --no-cache` passed. One upstream TestClient/httpx deprecation warning remains; dependencies were not changed. Cache disabling avoids an existing local pytest cache access warning.
- Added docs/VALIDATION.md. Initial hardening only ran SQLite/synthetic/model-double checks; subsequent Docker milestones supply runtime evidence. Field calibration and real YOLO inference remain unverified; mobile host building has since passed.

## Offline roadmap milestone — 2026-10-01

- Implemented manifest validation, safe CPU feature extraction, versioned embedding archives, exact-cosine candidate matching and explicit threshold/error reports. Tests cover split/session leakage, duplicate/changed bytes, paths, unreviewed captures, mixed species, disabled sheep, checksum failures, normalization, ambiguity, known/unknown errors, artifact/config mismatch and no-overwrite evidence.
- Actual official-weight CPU extraction ran with Docker networking disabled. Evidence: data/research/resnet18-smoke.json, dimensions 512 and repeat cosine 1.0. This is a deterministic feature smoke check on one licensed stock photograph, not recognition accuracy. No account, paid API, cloud service, or cattle/sheep model training was used.
- Final tests: `.\.venv\Scripts\python.exe -m pytest -c research/pyproject.toml backend/tests research/tests -q -p no:cacheprovider` → **82 passed**, one known TestClient/httpx deprecation warning. `.\.venv\Scripts\python.exe -m ruff check backend research tools --no-cache` → passed.
- Phase 3/4 groundwork: documented attack classes, genuine/attack separation, scale-weight/camera/view ground truth, and dated market-source requirements; added empty annotation CSV templates. No liveness/weight/valuation software claims without the roadmap's data/reliability prerequisites.
- Public sources examined: Zenodo 6324361 advertises 4923 crops/268 identities but session/rights prerequisites were not established and API retrieval timed out; ReCowGnition requires an access request and non-commercial terms. No request, credential submission, unknown-license download, or guessed session assignment was made. See docs/PHASE2_RESEARCH.md for links.
- Next action after data becomes available: review rights and identity/session ground truth, produce and validate the manifest, extract baseline vectors, choose thresholds on validation, and report held-out known/unknown errors and cohort counts. More feature implementation cannot substitute for these missing empirical inputs. Phone repair remains only the native mobile-test blocker.

## Authenticated registry milestone — 2026-10-01

- Added keyed operator/admin roles, registrations/status (open/insured/collateral), version-checked admin review, exact-pixel replay flags, bounded lists and append-only audit. Capture/audit mutation is blocked by migration triggers (PostgreSQL/SQLite); ORM capture edits also fail. Whole requests are bounded before multipart parsing; raw validation inputs are omitted globally.
- Backend suite: 59 passed, including preservation/backfill of a legacy 0001 capture, ORM/raw-SQL immutability, role/operator enforcement, stale version conflicts and duplicate review. Existing storage rollback tests still pass. No new model data was needed.
- Actual isolated Docker/PostgreSQL verification: migration 0002 applied to the retained verification volume; authenticated real JPEG upload/QC/pending_model/file/DB checked again. Evidence: data/verification/evidence/65a9351f-ded9-42dd-a248-827d97da7af4.json. Synthetic registration/replay/admin check verified 401/403/409, insured status, exact reuse review and PostgreSQL rejecting operator mutation. Evidence: data/verification/evidence/controls-d53b4892-0a8b-47c9-8309-90dfd636769e.json. Tests retain records and never merge/delete animal data.
- Flutter client sends operator key/OPERATOR_ID. Subsequent advisory milestone below verifies host/static/build checks and normal-backend rollout. Physical testing remains blocked.

## Formula/valuation milestone — 2026-10-01

- Added deterministic adult-cattle Schoorl/Trukhanovsky calculation, calibrated/mock 3D keypoint-to-cm pipeline, carcass scenario ranges and Decimal price math. Configs and shared code are species-aware; sheep remains disabled. No keypoint detector, single-photo 3D reconstruction or accuracy claim was built.
- Admin quote and operator calculation/read endpoints work. Additive migration 0003 stores append-only market history/audit without a seeded price. Final rollout below applied it to normal collection while preserving existing captures/data.
- Backend suite: 81 passed (synthetic/manual math examples, geometry confidence/degeneracy, input/source/role validation, stale quotes, yield and rounding, sheep disabled, plus regressions/migrations). Actual Docker/PostgreSQL quote/create/conflict/valuation test passed: data/verification/evidence/controls-6a7d65ab-0056-47dd-896a-31cc0902bf6c.json. Synthetic 180 cm girth/150 cm length/dairy factor gives 540 kg, with synthetic carcass rate 100 giving 27000–31320 scenario value. This is arithmetic proof only, not actual cattle calibration or market pricing.
- Formula sources/commands/measurement limitations: docs/WEIGHT_AND_VALUATION.md. Next independent task: advisory image/device/GPS anti-spoof groundwork; micro-movement/breathing stays blocked on video data.

## Advisory/security milestone — 2026-10-01

- Implemented per-scan immutable risk signals/config snapshot and optional typed device/GPS evidence. Native Android MethodChannel checks Build/root hints; iOS remains unsupported/unknown. Geolocator reports mock flag/accuracy/fix time; capture API operator is bound to auth principal. Added admin stored-image SHA-256 integrity inspection (matched/mismatch/missing/unavailable legacy), no external notarization claim.
- Final Python suite: 128 passed, one known TestClient/httpx deprecation warning; Ruff passed. Flutter analyze --no-pub: no issues; flutter test --no-pub: 7 passed, including mock channel failures/unknown behavior. flutter build apk --debug --no-pub succeeded in 778.5 seconds; only upstream Java/deprecation warnings, no cross-drive crash. Artifact: mobile/build/app/outputs/flutter-apk/app-debug.apk (ignored), SHA-256 f261401b955c9feecdb71225ca056fce1ff893469efb467e5d83034b989667b3. It was compiled without an API_TOKEN; rebuild with operator token for runtime testing. No device was connected or emulator created.
- Final Docker real cattle-photo upload/QC/DB/file/source-hash check: data/verification/evidence/7fe42c24-4353-4df4-9b7a-38b1a2e44b7a.json. Synthetic root/emulator/mock-GPS, sinusoidal upload, status/duplicate/price/formula checks: controls-e8cfbb7e-baf6-4d41-b1cb-022704f61261.json in the same evidence folder. Actual PostgreSQL concurrent uploads found exact reuse [0,1], status edits returned [200,409], price edits [201,409], admin stored-image integrity matched: concurrency-65781f3d-2672-49f4-becb-78dd5e6114f1.json. A transient registry TLS timeout succeeded on retry. No actual photographed-screen or cattle presentation attack was tested.
- Normal port-8000 stack rebuilt/migrated to 0003; both containers healthy, health HTTP 200 database ok, authenticated species 200 and anonymous species 401. All 43 backend/migration/config hashes match tested source. Normal captures before/after remain 0, market rates remain 0; synthetic data/prices only exist in the separate verification volume/storage. Preserved pg_dump backup: data/backups/20261001-211413/pre-controls.sql (3098 bytes). Verification containers are stopped after final checks; volumes/images/evidence retained. No real user data was deleted.
- Local commits 1ba94d8 and 5e01b0a plus the final advisory/verification commit that contains this update; no push. Requested data-independent work is exhausted. Next steps require a device for native runtime, labeled genuine/attack videos for reliable liveness, measured scale-weight/calibrated geometry for formula error, and a reviewed multi-session identity dataset before further embedding/matching. API admin workflows remain available for synthetic/manual review. No unresolved routine decision requires Sardorbek; obtain a real market source/rate before valuation use rather than treating the synthetic test rate as current pricing.
