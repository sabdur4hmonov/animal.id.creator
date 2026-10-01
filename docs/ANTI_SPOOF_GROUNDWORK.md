# Advisory presentation/device/location signals

The server runs real image analysis on accepted frames but returns liveness_verdict=not_assessed, presentation_medium=undetermined and real_world_accuracy_verified=false. Flags do not establish genuine/attack certainty and do not reject uploads. This preserves collection while we gather labeled genuine and attack examples. No anti-spoof confidence is manufactured. Motion, breathing and micro-movement remain blocked_on_labeled_video_dataset.

Shared code reads `security_configs/<species>.yaml`; cattle is enabled and sheep disabled with the same schema. Thresholds are prototypes, not farm-calibrated operating points. Bounded-resolution analysis is separate from authoritative blur/exposure QC:

- Moiré candidate: Hann-windowed grayscale Fourier power; concentration in eight largest bins of a middle/high-frequency band flags periodic texture. Screen interference can cause periodic energy, but ordinary patterns can too, and screens can lack moiré.
- Reflection candidate: largest connected bright, low-saturation region. Glossy screens/prints can reflect lights; wet noses and natural lighting can create highlights too. This does not establish the medium.
- Paper/screen boundary candidate: convex quadrilateral edges within configured area bounds. Printed frames/displays can show rectangles; fences/structures can also trigger. Borderless presentations can escape the check.

Tests synthesize sinusoidal texture, a white rectangular patch and random/flat controls. They verify computation/flags, not photographed-screen vs live-animal discrimination. No actual screen/paper photograph or animal attack capture was made. Docker uploads of these synthetic inputs verify persisted advisory output, not attack accuracy.

Android's MethodChannel reports emulator Build/model/fingerprint hints and root test-key/su/Magisk-path hints. Host tests mock the channel and test unknown/failure behavior. These heuristics are bypassable, with false positives/negatives: false does not prove trusted hardware. iOS reports unsupported/null rather than a fabricated clean result. No device attestation service or external account was used. [Android Play Integrity](https://developer.android.com/google/play/integrity/overview) is a separate future option; this module does not implement it.

Geolocator records native mock-location flag, accuracy and fix timestamp with each frame. Android's [Location.isMock](https://developer.android.com/reference/android/location/Location#isMock()) describes a mock-provider indicator, not cryptographic location proof. Optional strict device/gps_evidence objects are retained immutably as client claims; absent fields remain unknown. A caller with an API key can forge them. client_evidence_trusted is always false; hardware_attestation is not implemented.

GPS checks flag reported mock fixes, poor accuracy, fix/capture-time mismatch, stale/future capture clocks, out-of-order captures, same-time position jumps and implausible inferred speed from the previous received same-operator/species scan. Haversine distance handles the antimeridian. Thresholds are configurable. Forged data, transport/clock error/shared keys can produce anomalies; concurrency can change the preceding scan. These are review evidence, not fake-GPS proof. Missing GPS is null with a location_missing flag, never invented coordinates.

The immutable config snapshot supports later calibration. Physical Android camera/GPS/root/emulator behavior and animal/attack sensitivity/specificity remain unverified until a device and labeled material are available. Do not turn these flags into a hard liveness gate without that validation.
