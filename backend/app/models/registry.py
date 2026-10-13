"""Mutable registry projection; immutable operation receipts/audit preserve history."""

from datetime import datetime

from sqlalchemy import JSON, BigInteger, CheckConstraint, DateTime, Enum, ForeignKeyConstraint, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class AnimalNumberCounter(Base):
    __tablename__ = "animal_number_counters"
    prefix: Mapped[str] = mapped_column(String(8), primary_key=True)
    last_number: Mapped[int] = mapped_column(BigInteger)
    __table_args__ = (CheckConstraint("last_number >= 1", name="animal_counter_positive"),)


class AnimalProfile(Base):
    __tablename__ = "animal_profiles"
    __table_args__ = (
        ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        CheckConstraint("lifecycle IN ('active', 'deceased', 'slaughtered')", name="animal_lifecycle_values"),
    )
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False), primary_key=True)
    animal_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    numbered_id: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True)
    lifecycle: Mapped[str] = mapped_column(String(16), default="active")
    owner: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    retired_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class RegistryReceipt(Base):
    __tablename__ = "registry_receipts"
    operator_id: Mapped[str] = mapped_column(String(100), primary_key=True)
    request_key: Mapped[str] = mapped_column(String(128), primary_key=True)
    payload_sha256: Mapped[str] = mapped_column(String(64))
    response: Mapped[dict] = mapped_column(JSON)
