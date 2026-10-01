# Progress

The authoritative session record is the root [PROGRESS.md](../PROGRESS.md). As of 2026-10-01, physical-device testing is paused indefinitely while Sardorbek's water-damaged phone is repaired or replaced. This is an external blocker; continue backend work independently. The setup below is historical resume context.

## Phase 1 — Data collection MVP

### Test setup (as of 2026-09-29)

- Testing runs on a **physical Android phone over USB** (USB debugging on). There is **no Android emulator**: the `Pixel_8_Pro` AVD was deleted on 2026-09-29. Don't create or troubleshoot an emulator in future sessions.
- Backend: `docker compose up --build` in `backend/` (API on port 8000).
- Phone → backend: `adb reverse tcp:8000 tcp:8000`, then `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000` from `mobile/`. Re-run `adb reverse` after every reconnect or adb restart; check with `adb reverse --list`.
- Known gap: `mobile/lib/api_client.dart` still falls back to the emulator address `http://10.0.2.2:8000` when `API_BASE_URL` isn't passed. Always pass it (or change the default).
