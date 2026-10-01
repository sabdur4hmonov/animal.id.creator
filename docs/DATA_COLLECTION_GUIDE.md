# Farm checklist — cattle identity pilot

**Sardorbek · current code/config: 2026-10-01.** Collect cattle only. No muzzle checkpoint exists: accepted originals are `pending_model`, not verified nose crops. This protocol's **100-animal floor** supports a first pilot; it cannot establish rare-error reliability. Required sample size depends on the error target ([NIST](https://www.nist.gov/publications/using-chebyshevs-inequality-determine-sample-size-biometric-evaluation-fingerprint-data)).

## 1. Before travelling

- [ ] Arrange **50 cattle at each of two farms**, owner permission, and the **same animals on days 0, 7 and 14**. A handler controls the animal; stop if close capture is unsafe.
- [ ] Bring a working phone, powered laptop running Docker/backend, USB cable and power banks. Follow [README setup](../README.md): operator token/ID, USB debugging and `adb reverse tcp:8000 tcp:8000`. Internet is unnecessary once dependencies are installed; the backend connection is necessary.
- [ ] At home, prove native camera → QC → upload works with a test label `TEST-SETUP-001`; exclude it from research. Confirm Saved/UUID and server image. **Do not travel assuming the untested physical-device flow works.** There is no durable offline queue; Retake/app restart can lose an unuploaded photo.
- [ ] Prepare a shuffled, independently verified ear-tag roster; assign the IDs below once. Keep the same ID across visits, ownership/farm changes and devices. Never label identity from nose similarity.

## 2. Fixed cohort and capture recipe

Use `F01-C001`…`F01-C050` and `F02-C001`…`F02-C050` (ASCII, no spaces). Assign numbers from the shuffled roster, not by breed/age.

| IDs at **each** farm | Research split | Purpose |
|---|---|---|
| C001–C020 | train | 40 animals total; never validation/test |
| C021–C030 | validation | 20 enrolled animals total |
| C031–C035 | validation | 10 unknown animals total; never gallery |
| C036–C045 | test | 20 enrolled animals total |
| C046–C050 | test | 10 unknown animals total; never gallery |

- [ ] For **every animal at every visit**, obtain **6 accepted, distinct photos**: 2 straight-on, 2 about 15° to its left, 2 about 15° to its right; camera at nose height. Reset/reframe between shots; no copied frames, augmentation or burst-as-new-session.
- [ ] Start **40–60 cm** away using the rear camera, no digital zoom. Adjust distance until **one complete muzzle occupies about ⅓–½ of frame width**, central nose texture and both nostrils visible, with **≥10% frame margin on every side**. These distances/angles are starting guidance, not tested model limits; framing/focus decides.
- [ ] Wait for autofocus; hold still; inspect nose texture at full size. Keep native high resolution. Count a shot only after local QC passes, server upload succeeds, and the nose is visibly unobstructed. Retake blur, deep shadow, glare, mud/hand/rope obstruction or a cut-off nostril even if QC passes.
- [ ] Record the UUID before Retake/next animal. Finish **18 accepted photos/animal = 1,800 originals**. If a visit/identity check fails, record the gap and revisit; do not fill it with duplicates or rename the session.

## 3. Labels and on-site ledger

Session ID = `F01-YYYYMMDD-V1` (then actual dates with V2/V3); F02 uses its own prefix. Each is a separate visit/day. Lighting changes and consecutive shots **do not** create independent sessions.

- [ ] Before **each** visit's muzzle shots, read the permanent tag with the handler. Use the phone's ordinary camera for tag + side-view references; do not upload/count these as muzzle captures. In `roster.csv` record `animal_id, permanent_tag, identity_verified_by, verification_time, reference_filename`; V1/V2/V3 must agree. Conflicting/unreadable/replaced tag → `identity_uncertain`; exclude until independently resolved.
- [ ] Per animal: breed, sex, birth date/estimated age, coat/markings, health/nose damage/soiling, owner/farm code and permission reference. Record unknown rather than guessing. If available, add actual scale kg/time/device and tape girth/straight length in cm; muzzle photos alone cannot establish weight.
- [ ] In `scans.csv`, one row/photo: `animal_id, species=cattle, session_id, farm_id, camera_id, shot_no, view(front/left15/right15), distance_cm, timestamp_with_timezone, operator_id, gps_latitude, gps_longitude, lighting, nose_condition, capture_uuid, server_file_path, upload_result`. Camera ID e.g. `PHONE-01`; operator ID must match its API key. Time example: `2026-10-08T09:15:00+05:00`; blank GPS means unavailable, never invented `0,0`.

The API accepts animal ID, species, timezone-aware timestamp, authenticated operator, nullable GPS and optional device/GPS evidence. **Session/farm/camera/tag/view are ledger fields, not upload JSON fields** (unknown JSON fields are rejected). Server supplies UUID, receipt time, QC/config snapshot, hashes and paths. It strips EXIF: do not rely on EXIF to recover labels later.

```text
Server originals (leave names/files unchanged):
data/cattle/F01-C021/<UTC-date>/<capture-uuid>_original.jpg

Separate research copies after manual nose review/cropping:
data/research/crops/cattle/F01-C021/F01-20261008-V1/01-front.jpg

Ledger + identity references (outside crops/):
data/research/field/roster.csv
data/research/field/scans.csv
data/research/field/references/F01-C021/F01-20261008-V1/tag.jpg
data/research/field/references/F01-C021/F01-20261008-V1/body.jpg
```

Research shot names: `01-front.jpg`, `02-front.jpg`, `03-left15.jpg`, `04-left15.jpg`, `05-right15.jpg`, `06-right15.jpg` (the animal's left/right). UTC date may differ from local date; session comes from the ledger. Never rename server evidence. Back up ledger, originals and database before leaving; verify 6 saved UUIDs per animal/visit.

## 4. What the code rejects / after-visit handoff

| Current cattle rule | Field action |
|---|---|
| JPEG/PNG; ≤15 MiB; ≤25 million pixels; long side ≥640, short side ≥480 | Native high-resolution photo; no screenshots/messaging compression |
| Laplacian variance ≥100 after resizing long side to ≤640 | Sharp **nose**, steady camera/animal; sharp background alone can pass |
| Grayscale mean 40–215; ≤60% pixels at ≤25; ≤60% at ≥230 | Open shade/diffuse light; avoid backlighting, flash glare and bright sky dominating frame |
| With a checkpoint: exactly one `muzzle`, confidence ≥0.5; box ≥128×128 and ≥1% of frame; ≥1% edge clearance; 10% crop padding | Whole single muzzle, generous margins; multiple/no muzzle or bad framing gives 422 |
| Detected crop repeats blur/lighting QC, minimum 128×128 | Check texture inside nose, not just whole-image QC; no checkpoint means these crop checks do not run |

- [ ] HTTP 201/`pending_model` means original saved only. 422 → read reason: fix labels or retake for QC/framing; 413 → file too large; 401/403 → token/operator; 503 → backend/storage/model. Spoof/GPS flags are advisory. Timeout → check with admin before repeating; retry can flag exact-image reuse.
- [ ] After visit, review/crop complete muzzles from originals into research copies; mark `reviewed_muzzle=true` only after actual review. Fill [muzzle_annotations.csv](../research/templates/muzzle_annotations.csv): sample ID = capture UUID; hash **research crop bytes**, image_path relative to `data/research/crops`, plus the roster's split/session/farm/camera. Preserve crop→original UUID linkage. Serialize as JSON using [research instructions](PHASE2_RESEARCH.md).
- [ ] For enrolled validation/test animals: **V1 = gallery; V2/V3 = query**. For unknown animals: **V2/V3 = query only**, archive V1 outside the evaluation manifest. Train animals: all visits `split=train, role=train`. Never share an animal across splits or a same-animal session between gallery/query. Tune threshold on validation, freeze it, then test once; report known misses/wrong accepts and unknown accepts with counts, not a claimed production accuracy.

## 5. Sheep — later, not this visit

- [ ] Keep sheep disabled. Later use separate IDs (`F01-S001`), `species=sheep`, the same visit/ledger scheme and separate manifests. Smaller/wool-obscured muzzles need fresh framing/QC calibration and a sheep checkpoint before enabling collection; do not assume cattle distance/thresholds/formulas work. Record breed, age and wool/nose obstruction; retain identity proof across visits. No sheep model work is part of this protocol.
