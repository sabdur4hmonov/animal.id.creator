from typing import Literal

from fastapi import HTTPException

Role = Literal["admin", "operator", "veterinar", "bank_viewer", "bank_officer"]
ROLES = ("admin", "operator", "veterinar", "bank_viewer", "bank_officer")


def require_role(principal, *roles):
    if principal.role not in roles:
        raise HTTPException(403, "This role cannot perform this action")
    return principal
