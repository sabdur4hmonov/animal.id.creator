from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from app.api.business import SessionDep
from app.core.auth import Principal
from app.core.rate_limit import allowed
from app.models.accounts import UserAccount
from app.schemas.login import LoginInput
from app.services.browser_sessions import digest, new_session, set_cookie
from app.services.login_attempts import login_attempt
from app.services.passwords import access_audit, dummy_hash, matches

router = APIRouter()


@router.post("/panel/login", dependencies=[Depends(login_attempt)])
def password_login(data: LoginInput, request: Request, session: SessionDep):
    if request.headers.get("X-Chorvam-Login") != "1":
        raise HTTPException(403, "Explicit JSON login required")
    settings = request.app.state.settings
    if not allowed(
        session,
        data.username,
        "account_login",
        settings.login_account_rate_requests,
        settings.login_account_rate_window_seconds,
    ):
        raise HTTPException(
            429,
            "Too many login attempts; retry later",
            headers={"Retry-After": str(settings.login_account_rate_window_seconds)},
        )
    account = session.get(UserAccount, data.username)
    valid = matches(settings, account.password_hash if account else dummy_hash(), data.password)
    if not valid or account is None or account.disabled_at:
        access_audit(session, "anonymous", account.username if account else "unknown", "login_failed")
        session.commit()
        raise HTTPException(401, "Invalid username or password")
    principal = Principal(
        operator_id=account.operator_id, role=account.role, token_sha256=digest(account.password_hash)
    )
    access_audit(session, account.operator_id, account.username, "login_succeeded")
    token, _ = new_session(session, principal, settings)
    response = JSONResponse({"ok": True}, headers={"Cache-Control": "no-store"})
    set_cookie(response, token, settings.browser_session_seconds)
    return response
