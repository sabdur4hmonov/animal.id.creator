"""Local API keys with separate operator/admin roles; no default credentials."""

import hashlib
import hmac
import json
from pathlib import Path
from typing import Annotated, Literal

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field


class Principal(BaseModel):
    model_config = ConfigDict(extra="forbid")
    operator_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$")
    role: Literal["operator", "admin"]
    token_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")


def load_credentials(path: Path) -> list[Principal]:
    if not path.is_file():
        return []  # Health remains available; protected endpoints fail closed.
    records = [Principal.model_validate(value) for value in json.loads(path.read_text("utf-8"))]
    if len({p.operator_id for p in records}) != len(records):
        raise ValueError("Duplicate authenticated operator IDs")
    if len({p.token_sha256 for p in records}) != len(records):
        raise ValueError("Each principal needs a distinct API key")
    return records


bearer = HTTPBearer(auto_error=False)


def authenticate(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> Principal:
    principals = request.app.state.credentials
    if not principals:
        raise HTTPException(503, "API credentials are not configured")
    if credentials and len(credentials.credentials) <= 512:
        digest = hashlib.sha256(credentials.credentials.encode()).hexdigest()
        for principal in principals:
            if hmac.compare_digest(principal.token_sha256, digest):
                return principal
    raise HTTPException(401, "Valid bearer API key required", headers={"WWW-Authenticate": "Bearer"})


PrincipalDep = Annotated[Principal, Depends(authenticate)]


def require_admin(principal: PrincipalDep) -> Principal:
    if principal.role != "admin":
        raise HTTPException(403, "Administrator role required")
    return principal


AdminDep = Annotated[Principal, Depends(require_admin)]
