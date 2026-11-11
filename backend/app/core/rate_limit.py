"""Database-backed fixed windows shared by all API workers; proxy headers untrusted here."""

import hashlib
import time

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.models.public_verification import RateWindow


def allowed(session, peer, scope, limit, seconds):
    key = hashlib.sha256(f"{scope}:{peer}".encode()).hexdigest()
    window = int(time.time()) // seconds * seconds
    insert = pg_insert if session.get_bind().dialect.name == "postgresql" else sqlite_insert
    hits = session.scalar(
        insert(RateWindow)
        .values(scope_key=key, window_start=window, hits=1)
        .on_conflict_do_update(
            index_elements=["scope_key", "window_start"], set_={"hits": RateWindow.hits + 1}
        )
        .returning(RateWindow.hits)
    )
    session.commit()
    return hits <= limit
