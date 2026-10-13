from datetime import UTC, datetime
from typing import Annotated

from pydantic import AfterValidator, AwareDatetime, BaseModel, ConfigDict


def safe_utc_timestamp(value: datetime) -> datetime:
    try:
        value.astimezone(UTC)
    except (OverflowError, ValueError) as exc:
        raise ValueError("Timestamp cannot be represented in UTC") from exc
    return value  # Keep the supplied offset; storage normalizes only after validation.


SafeTimestamp = Annotated[AwareDatetime, AfterValidator(safe_utc_timestamp)]


class StrictInput(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
