import pytest
from pydantic import ValidationError

from app.core.species import NumberingConfig
from app.services.numbering import capacity, format_number, reserved_number

BLOCK = 99_999_999


@pytest.mark.parametrize("ordinal,expected", [
    (1, "MAA00000001"), (BLOCK, "MAA99999999"),
    (BLOCK + 1, "MAB00000001"), (26 * BLOCK, "MAZ99999999"),
    (26 * BLOCK + 1, "MBA00000001"), (676 * BLOCK, "MZZ99999999"),
])
def test_fixed_width_series_boundaries(config, ordinal, expected):
    assert format_number(config.numbering, ordinal) == expected
    assert len(expected) == 11
    assert capacity(config.numbering) == 67_599_999_324


@pytest.mark.parametrize("ordinal", [0, -1, 676 * BLOCK + 1])
def test_exhaustion_never_wraps(config, ordinal):
    with pytest.raises(ValueError):
        format_number(config.numbering, ordinal)


def test_original_config_without_series_still_formats_legacy_numbers():
    old = NumberingConfig(prefix="M", digits=8)
    assert old.series_letters == 0
    assert format_number(old, 1) == "M00000001"
    assert capacity(old) == BLOCK


@pytest.mark.parametrize("value", [-1, 3, float("inf")])
def test_config_rejects_unsupported_series_size(value):
    with pytest.raises(ValidationError):
        NumberingConfig(prefix="M", digits=8, series_letters=value)


@pytest.mark.parametrize("animal_id", ["M00000001", "m00000001", "MAA00000001", "mab00000001", "MZZ1"])
def test_both_legacy_and_series_namespaces_are_reserved(config, animal_id):
    assert reserved_number(config, animal_id)


def test_legacy_non_numeric_labels_stay_available(config):
    assert not reserved_number(config, "F01-C001")
    assert not reserved_number(config, "M-FARM-1")
