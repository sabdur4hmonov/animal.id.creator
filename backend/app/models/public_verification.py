"""Opaque public record capabilities and immutable revocation evidence."""

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, ForeignKeyConstraint, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class SlaughterCode(Base):
    __tablename__ = "slaughter_codes"
    __table_args__ = (
        ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        Index("slaughter_codes_animal", "species", "animal_id"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False))
    animal_id: Mapped[str] = mapped_column(String(64))
    token_sha256: Mapped[str] = mapped_column(String(64), unique=True)
    issued_by: Mapped[str] = mapped_column(String(100))
    request_key: Mapped[str] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class CodeRevocation(Base):
    __tablename__ = "code_revocations"
    code_id: Mapped[str] = mapped_column(ForeignKey("slaughter_codes.id"), primary_key=True)
    actor_id: Mapped[str] = mapped_column(String(100))
    reason: Mapped[str] = mapped_column(String(1000))
    revoked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class RateWindow(Base):
    __tablename__ = "rate_windows"
    scope_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    window_start: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    hits: Mapped[int] = mapped_column(Integer)
