# Evidence needed for subsequent phases

## Phase 2: cattle identity

Provide reviewed muzzle crops, an independently verified animal label, acquisition session/date, camera and farm identifiers, review status and content checksum. Keep bursts/near-duplicates in one session. Partition animals before tuning; use separate validation and held-out test identities, with gallery/query captures across sessions and unknown animals outside the gallery. Measure errors by breed/farm/device/exposure and gallery size. A stock photograph or duplicated/augmented image is not repeated-capture evidence. Decide operational false-identification/miss limits using measured validation curves before integrating matching into collection.

The existing Phase 1 capture record has a UTC timestamp and operator ID but no trusted farm/device/identity-review ground truth. Preserve collection metadata; maintain richer research annotations outside the production schema until the dataset format has been exercised. `muzzle_annotations.csv` is a checklist, not fabricated data.

## Phase 3: liveness/anti-spoofing

Initial threat model: printed muzzle photographs, photos/video on a display, reused genuine files submitted directly to the unauthenticated API, and repeated/replayed requests. Camera-only UI cannot establish that an API upload came from a live animal. Evaluate each presentation type, lighting condition and unseen display/camera combination separately. Separate genuine/attack sessions and source animals across training, validation and test; track which genuine source produced each attack to avoid leakage.

Collect consented genuine sessions and controlled presentation-attack examples using `liveness_annotations.csv`. Record medium, replay source, session, device, lighting and independent label. Report attack acceptance and genuine rejection at the same frozen threshold. Single-image texture checks and future motion/challenge checks have different acquisition requirements; defer that product choice until attack data reveals the limitations. No liveness detector or “live” flag has been added because measured reliability is a roadmap prerequisite.

## Phase 4: weight and valuation

Collect full-body reference views paired with actual scale measurements taken close to image acquisition, plus animal/session, camera calibration or reference scale, view, breed, age/sex where known and measurement provenance. Split by animal and acquisition site/session, and evaluate absolute error, systematic bias and interval coverage. Muzzle identity crops alone are not the required weight training inputs. Use `weight_annotations.csv` as a checklist. Do not fabricate weights from IDs or image dimensions.

Valuation needs independently sourced, dated market observations with region, currency, unit, grade and any conversion assumptions, plus validated weight uncertainty. No prices were purchased/fetched or monetary estimates implemented. Paid sources/credentials require Sardorbek; market source selection and model deployment should follow measured usefulness and uncertainty, not an arbitrary coefficient.

## Shared blocking inputs

Current repo has no reviewed multi-animal/multi-session identity dataset, genuine/attack labels, or image/scale-weight pairs. None can be replaced by unit tests or the single upload verification image. The repaired/replacement phone is needed only for native capture testing; backend/research tooling already runs without it. Sheep collection, training, activation and pilot remain later work and disabled.
