"""Registration state is separate from immutable scan evidence."""

from datetime import datetime

from sqlalchemy import JSON, CheckConstraint, DateTime, Enum, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class Animal(Base):
    __tablename__ = "animals"
    __table_args__ = (
        CheckConstraint("status IN ('open', 'insured', 'collateral')", name="animal_status_values"),
        CheckConstraint("version >= 1", name="animal_version_positive"),
    )
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False), primary_key=True)
    animal_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    status: Mapped[str] = mapped_column(String(16), default="open")
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    registered_by: Mapped[str | None] = mapped_column(String(100), nullable=True)


class AuditEvent(Base):
    __tablename__ = "audit_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False))
    animal_id: Mapped[str] = mapped_column(String(64))
    action: Mapped[str] = mapped_column(String(64))
    actor_id: Mapped[str] = mapped_column(String(100))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    details: Mapped[dict] = mapped_column(JSON)


class DuplicateCase(Base):
    __tablename__ = "duplicate_cases"
    __table_args__ = (
        UniqueConstraint("capture_id", "matched_capture_id", name="duplicate_pair_unique"),
        CheckConstraint("state IN ('pending', 'confirmed', 'dismissed')", name="duplicate_state_values"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False))
    animal_id: Mapped[str] = mapped_column(String(64))
    capture_id: Mapped[str] = mapped_column(ForeignKey("captures.id"))
    matched_capture_id: Mapped[str | None] = mapped_column(ForeignKey("captures.id"), nullable=True)
    reason: Mapped[str] = mapped_column(String(64))
    state: Mapped[str] = mapped_column(String(16), default="pending")
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    review_note: Mapped[str | None] = mapped_column(String(1000), nullable=True)
