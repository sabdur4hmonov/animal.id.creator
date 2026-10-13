"""Format a forward-only ordinal without resetting at a letter-series boundary."""

import re


def capacity(numbering):
    return (10**numbering.digits - 1) * 26**numbering.series_letters


def format_number(numbering, ordinal):
    if not 1 <= ordinal <= capacity(numbering):
        raise ValueError("Animal numbering ordinal is outside the configured range")
    block, number = divmod(ordinal - 1, 10**numbering.digits - 1)
    letters = []
    for _ in range(numbering.series_letters):
        block, letter = divmod(block, 26)
        letters.append(chr(ord("A") + letter))
    return f"{numbering.prefix}{''.join(reversed(letters))}{number + 1:0{numbering.digits}d}"


def reserved_number(config, animal_id):
    # Retain the old numeric namespace, including case/width look-alikes.
    letters = rf"[A-Z]{{0,{config.numbering.series_letters}}}"
    pattern = re.escape(config.numbering.prefix) + letters + r"[0-9]+"
    return re.fullmatch(pattern, animal_id.upper()) is not None
