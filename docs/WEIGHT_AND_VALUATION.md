# Formula weight and scenario valuation

These authenticated calculations implement measurement formulas, not a trained vision model. Field error is unverified. Inputs describe adult cattle and either supplied tape/stick measurements in centimeters or calibrated 3D points. Breed, age, pose, measurement technique and reconstruction affect accuracy; calibrate against actual scale weights before relying on results.

The user's “Truxanov” is treated as Trukhanovsky: live kg = chest girth cm × straight body length cm × breed factor / 100, with configured dairy factor 2 and beef factor 2.5. See [Bezsonov et al., 2021, formula 1](https://journals.uran.ua/eejet/article/view/247648). Schoorl uses live kg = (chest girth cm + 22)² / 100, the kg convention in [ISTAP 2017 proceedings](https://journal.ugm.ac.id/istapproceeding/article/download/30043/18108). Similar names/variants are not silently interchangeable. No body-condition correction is guessed.

`business_configs/<species>.yaml` holds coefficients, keypoint confidence cutoff and carcass-yield scenarios. Cattle is enabled; sheep is disabled with an empty breed-factor map and placeholder formula fields, not sheep estimates. No sheep model or processing branch exists. User-requested yield ranges are cattle 50–58% and disabled sheep 45–52%. These are assumptions, not measured boneless-meat yield or confidence intervals. Carcass kg = live kg × yield; carcass scenario value = carcass kg × carcass price/kg. Money uses Decimal rounded to 2 decimals; stored rates retain 4 decimals. Currency is explicit with no conversion.

POST `/api/v1/valuation` with an operator/admin key:

```json
{"species":"cattle","method":"trukhanovsky","adult":true,"breed_category":"dairy","chest_girth_cm":"180","body_length_cm":"150","currency":"UZS"}
```

This yields 540 live kg by arithmetic and 270–313.2 carcass kg. Schoorl on 180 cm yields 408.04 kg, illustrating why estimates are method-specific. Response includes measurements, coefficient/config snapshot, rate ID/source/time, scenario range and `real_world_accuracy_verified: false`. This is not a loan decision, insurance certificate or veterinary dosage recommendation. Missing price returns 409; sheep/calves, unsupported breed factors, invalid numbers/geometry and mixed measurement sources fail validation.

The optional keypoint pipeline requires `coordinate_system: calibrated_3d`, a reference segment plus known cm length, body endpoints and an ordered closed chest contour. Closure is implicit: do not repeat its first point. Points have x/y/z and confidence. Scale is reference cm / reference coordinate distance; body length is scaled endpoint distance; girth is scaled closed-polyline length. Zero calibration, repeated/collinear contour points, low confidence and out-of-range measurements fail. Caller must supply a genuine complete 3D reconstruction: this service does not recover one from an ordinary photograph. Side-view width/height or unscaled pixels cannot establish girth. Synthetic square/segment tests verify arithmetic; contour ordering/completeness and anatomy remain field checks.

Since the 2026-10-13 audit repair, a chest contour must also form a simple, planar
cross-section. Self-intersections, overlapping/retraced edges and materially non-planar
inputs are rejected. Planarity and numerical tolerances are in each species business config;
points are never automatically reordered or replaced by a hull. Geometry validity does not
establish anatomical completeness or measured animal accuracy.

No market price is seeded. In Swagger Authorize with an admin key, then POST `/api/v1/admin/market-rates`:

```json
{"species":"cattle","currency":"UZS","basis":"carcass","price_per_kg":"100.0000","observed_at":"2026-10-01T10:00:00Z","source":"Synthetic example only","expected_latest_id":null}
```

100 is a synthetic example, not today's price. Fetch GET `/api/v1/market-rates/cattle?currency=UZS` first. Updates supply that ID as expected_latest_id; stale edits return 409. Accepted rates and audit events are append-only. PostgreSQL locks serialize same-species/currency admin edits. Observations over five minutes in the future are rejected. The newest accepted quote is used; observed_at/source are returned for freshness review. There is no automatic market feed, freshness guarantee, currency conversion, tax/fee calculation or boneless-meat-price conversion. Price accuracy remains an administrator assertion.

Real scale-weight/calibration data and market-source agreement remain external prerequisites. They do not block testing this deterministic engine.
