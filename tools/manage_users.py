"""Local administrative CLI. Passwords are read privately, never command arguments."""

import argparse
import getpass
import re
import sys
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.core.auth import load_credentials
from app.core.database import SessionLocal
from app.core.roles import ROLES
from app.core.settings import get_settings
from app.models.accounts import UserAccount
from app.models.portal import BrowserSession
from app.services.idempotency import lock_request
from app.services.passwords import access_audit, password_hash


def apply_change(
    session,
    settings,
    command,
    username,
    *,
    actor,
    operator_id=None,
    role=None,
    password=None,
):
    lock_request(session, "account_policy", "local_administrator")
    if not re.fullmatch(r"[a-z0-9][a-z0-9_.-]{0,63}", username):
        raise ValueError("Username must be lowercase ASCII, 1–64 characters")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", actor):
        raise ValueError("Provide a safe administrator actor ID")
    account = session.get(UserAccount, username)
    if command == "create":
        if account:
            raise ValueError("Account exists; it was not overwritten")
        if (
            role not in ROLES
            or not operator_id
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", operator_id)
        ):
            raise ValueError("Valid role and immutable operator ID required")
        if any(
            p.operator_id == operator_id
            for p in load_credentials(settings.auth_config_path)
        ):
            raise ValueError(
                "Operator ID already belongs to an API-key principal; use a distinct identity"
            )
        if session.scalar(
            select(UserAccount.username).where(UserAccount.operator_id == operator_id)
        ):
            raise ValueError("Operator ID already belongs to another account")
        account = UserAccount(
            username=username,
            operator_id=operator_id,
            role=role,
            password_hash=password_hash(settings, password or ""),
            created_at=datetime.now(UTC),
        )
        session.add(account)
        access_audit(
            session,
            actor,
            username,
            "account_created",
            role=role,
            operator_id=operator_id,
        )
    else:
        if account is None:
            raise ValueError("Account not found")
        if (
            command in ("disable", "set-role")
            and account.role == "admin"
            and account.disabled_at is None
            and (command == "disable" or role != "admin")
        ):
            other = session.scalar(
                select(UserAccount.username)
                .where(
                    UserAccount.role == "admin",
                    UserAccount.disabled_at.is_(None),
                    UserAccount.username != username,
                )
                .limit(1)
            )
            if other is None:
                raise ValueError("Keep at least one enabled password administrator")
        before = account.role
        if command == "set-role":
            if role not in ROLES:
                raise ValueError("Unknown role")
            account.role = role
        elif command == "disable":
            account.disabled_at = datetime.now(UTC)
        elif command == "reset-password":
            account.password_hash = password_hash(settings, password or "")
        else:
            raise ValueError("Unknown command")
        for browser in session.scalars(
            select(BrowserSession).where(
                BrowserSession.operator_id == account.operator_id,
                BrowserSession.revoked_at.is_(None),
            )
        ):
            browser.revoked_at = datetime.now(UTC)
        access_audit(
            session,
            actor,
            username,
            "account_" + command.replace("-", "_"),
            before_role=before,
            after_role=account.role,
        )
    session.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=["create", "set-role", "disable", "reset-password"]
    )
    parser.add_argument("--username", required=True)
    parser.add_argument(
        "--actor", required=True, help="Administrator performing this local action"
    )
    parser.add_argument("--operator-id", help="New account only; remains immutable")
    parser.add_argument("--role", choices=ROLES)
    parser.add_argument(
        "--password-file",
        type=Path,
        help="Optional private UTF-8 file; never commit it",
    )
    args = parser.parse_args()
    value = None
    if args.command in ("create", "reset-password"):
        if args.password_file:
            value = args.password_file.read_text("utf-8").rstrip("\r\n")
        else:
            value = getpass.getpass("New password (12+ characters): ")
            if value != getpass.getpass("Repeat password: "):
                parser.error("Passwords differ; nothing changed")
    try:
        with SessionLocal() as session:
            apply_change(
                session,
                get_settings(),
                args.command,
                args.username.lower(),
                actor=args.actor,
                operator_id=args.operator_id,
                role=args.role,
                password=value,
            )
            session.commit()
    except ValueError as exc:
        parser.error(str(exc))
    print("Account change committed with access audit. No password or hash printed.")


if __name__ == "__main__":
    main()
