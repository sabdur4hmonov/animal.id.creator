"""Short-lived private browser sessions and immutable compact field summaries."""

from datetime import datetime

from sqlalchemy import JSON, DateTime, Enum, ForeignKeyConstraint, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class BrowserSession(Base):
    __tablename__ = "browser_sessions"
    token_sha256: Mapped[str] = mapped_column(String(64), primary_key=True)
    credential_sha256: Mapped[str] = mapped_column(String(64))
    operator_id: Mapped[str] = mapped_column(String(100))
    csrf: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class FieldSummary(Base):
    __tablename__ = "field_summaries"
    __table_args__ = (
        ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        UniqueConstraint("actor_id", "local_event_key", name="field_summary_local_unique"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False), index=True)
    animal_id: Mapped[str] = mapped_column(String(64), index=True)
    actor_id: Mapped[str] = mapped_column(String(100))
    local_event_key: Mapped[str] = mapped_column(String(32))
    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    payload: Mapped[dict] = mapped_column(JSON)
