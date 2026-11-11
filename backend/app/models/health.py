"""Append-only reported observations, never an automatic diagnosis."""

from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, ForeignKeyConstraint, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class HealthEvent(Base):
    __tablename__ = "health_events"
    __table_args__ = (
        ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        UniqueConstraint("correction_of", name="health_single_successor"),
        UniqueConstraint("actor_id", "local_event_key", name="health_client_event_unique"),
        Index("health_animal_date", "species", "animal_id", "event_date"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False))
    animal_id: Mapped[str] = mapped_column(String(64))
    local_event_key: Mapped[str] = mapped_column(String(32))
    kind: Mapped[str] = mapped_column(String(24))
    event_date: Mapped[date] = mapped_column(Date)
    description: Mapped[str] = mapped_column(String(500))
    veterinarian_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    notes: Mapped[str] = mapped_column(String(1000))
    correction_of: Mapped[str | None] = mapped_column(ForeignKey("health_events.id"), nullable=True)
    actor_id: Mapped[str] = mapped_column(String(100))
    actor_role: Mapped[str] = mapped_column(String(24))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
