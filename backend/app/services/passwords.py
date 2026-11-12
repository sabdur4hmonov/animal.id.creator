"""Explicit Argon2id parameters; no default passwords or exported hashes."""

import secrets
from datetime import UTC, datetime
from functools import lru_cache
from uuid import uuid4

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from argon2.low_level import Type

from app.models.accounts import AccessAudit


def hasher(settings):
    return PasswordHasher(
        time_cost=settings.argon_time_cost,
        memory_cost=settings.argon_memory_kib,
        parallelism=settings.argon_parallelism,
        type=Type.ID,
    )


def password_hash(settings, password):
    if not 12 <= len(password) <= 256 or not password.strip() or any(ord(c) < 32 for c in password):
        raise ValueError("Password must contain 12–256 characters without control characters")
    return hasher(settings).hash(password)


@lru_cache(maxsize=1)
def dummy_hash():
    # A valid unknown-user hash prevents a cheap username timing oracle.
    return PasswordHasher().hash(secrets.token_urlsafe(32))


def matches(settings, encoded, password):
    try:
        return hasher(settings).verify(encoded, password)
    except (VerificationError, InvalidHashError):
        return False


def access_audit(session, actor, subject, action, **details):
    session.add(
        AccessAudit(
            id=str(uuid4()),
            actor_id=actor,
            subject=subject,
            action=action,
            received_at=datetime.now(UTC),
            details=details,
        )
    )
