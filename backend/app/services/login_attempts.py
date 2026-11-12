from typing import Annotated

from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.database import get_session
from app.core.rate_limit import allowed


def login_attempt(request: Request, session: Annotated[Session, Depends(get_session)]):
    settings = request.app.state.settings
    expected = settings.public_origin.rstrip("/") or str(request.base_url).rstrip("/")
    if request.headers.get("Origin") not in (None, expected):
        raise HTTPException(403, "Same-origin login required")
    peer = request.client.host if request.client else "unknown"
    if not allowed(
        session, peer, "portal_login", settings.login_rate_requests, settings.login_rate_window_seconds
    ):
        raise HTTPException(
            429,
            "Too many login attempts; retry later",
            headers={"Retry-After": str(settings.login_rate_window_seconds)},
        )
