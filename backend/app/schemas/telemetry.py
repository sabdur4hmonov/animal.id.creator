from typing import Literal

from pydantic import AwareDatetime, Field, StrictBool

from app.schemas.common import StrictInput


class DeviceSignals(StrictInput):
    source: Literal["android_heuristic", "unsupported"]
    is_rooted: StrictBool | None = None
    is_emulator: StrictBool | None = None


class GPSEvidence(StrictInput):
    source: Literal["android_location", "ios_location", "unknown"]
    is_mock: StrictBool | None = None
    accuracy_m: float | None = Field(default=None, ge=0, le=100000)
    observed_at: AwareDatetime | None = None
