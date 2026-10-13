import json

import pytest
from pydantic import ValidationError

from app.main import app
from app.schemas.common import safe_utc_timestamp
from app.schemas.valuation import MarketRateInput


@pytest.mark.parametrize("timestamp", ["0001-01-01T00:00:00+14:00", "9999-12-31T23:59:59-14:00"])
@pytest.mark.parametrize("field", ["timestamp", "gps_observed_at"])
def test_unrepresentable_utc_upload_returns_422(client, metadata, jpeg, timestamp, field):
    if field == "timestamp":
        metadata["timestamp"] = timestamp
    else:
        metadata["gps_evidence"] = {"source": "unknown", "observed_at": timestamp}
    response = client.post("/api/v1/captures", headers={"Idempotency-Key": "d" * 32},
                           data={"metadata": json.dumps(metadata)}, files={"image": ("x.jpg", jpeg)})
    assert response.status_code == 422
    assert not list(app.state.settings.storage_root.rglob("*.jpg"))


@pytest.mark.parametrize("timestamp", ["0001-01-01T00:00:00+14:00", "9999-12-31T23:59:59-14:00"])
def test_market_timestamp_rejects_utc_overflow(timestamp):
    with pytest.raises(ValidationError, match="represented in UTC"):
        MarketRateInput(species="cattle", currency="UZS", basis="carcass", price_per_kg="100",
                        observed_at=timestamp, source="Synthetic audit")


def test_ordinary_timestamp_keeps_original_offset():
    from datetime import datetime
    value = datetime.fromisoformat("2026-10-13T09:00:00+05:00")
    assert safe_utc_timestamp(value) is value
