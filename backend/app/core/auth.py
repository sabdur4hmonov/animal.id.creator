"""Preserved bearer API keys plus revocable browser sessions and explicit roles."""

import hashlib
import hmac
import json
from pathlib import Path
from typing import Annotated

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_session
from app.core.roles import Role, require_role
from app.models.accounts import UserAccount
from app.services.browser_sessions import browser_principal


class Principal(BaseModel):
    model_config = ConfigDict(extra="forbid")
    operator_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$")
    role: Role
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
    session: Annotated[Session, Depends(get_session)],
) -> Principal:
    principals = request.app.state.credentials
    if credentials and len(credentials.credentials) <= 512:
        digest = hashlib.sha256(credentials.credentials.encode()).hexdigest()
        for principal in principals:
            if hmac.compare_digest(principal.token_sha256, digest):
                return principal
    if not request.headers.get("Authorization"):
        principal = browser_principal(request, session)
        if principal:
            return principal
    if not principals and not session.scalar(select(UserAccount.username).limit(1)):
        raise HTTPException(503, "API credentials are not configured")
    raise HTTPException(401, "Valid bearer API key required", headers={"WWW-Authenticate": "Bearer"})


PrincipalDep = Annotated[Principal, Depends(authenticate)]


def require_admin(principal: PrincipalDep) -> Principal:
    if principal.role != "admin":
        raise HTTPException(403, "Administrator role required")
    return principal


AdminDep = Annotated[Principal, Depends(require_admin)]


def require_operator(principal: PrincipalDep) -> Principal:
    return require_role(principal, "admin", "operator")


def require_finance(principal: PrincipalDep) -> Principal:
    return require_role(principal, "admin", "bank_officer")


OperatorDep = Annotated[Principal, Depends(require_operator)]
FinanceDep = Annotated[Principal, Depends(require_finance)]
