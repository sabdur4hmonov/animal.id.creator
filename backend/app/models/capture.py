from datetime import datetime

from sqlalchemy import JSON, CheckConstraint, DateTime, Enum, Float, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class Capture(Base):
    __tablename__ = "captures"
    __table_args__ = (
        CheckConstraint("image_quality_score >= 0 AND image_quality_score <= 1", name="quality_range"),
        CheckConstraint("crop_status IN ('pending_model', 'cropped')", name="crop_status_values"),
        Index("ix_captures_species_animal_timestamp", "species", "animal_id", "timestamp"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    animal_id: Mapped[str] = mapped_column(String(64))
    species: Mapped[Species] = mapped_column(
        Enum(Species, native_enum=False, create_constraint=True, name="species")
    )
    gps: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    operator_id: Mapped[str] = mapped_column(String(100))
    image_quality_score: Mapped[float] = mapped_column(Float)
    file_path: Mapped[str] = mapped_column(String(512))
    crop_path: Mapped[str | None] = mapped_column(String(512), nullable=True)
    crop_status: Mapped[str] = mapped_column(String(32))
    quality: Mapped[dict] = mapped_column(JSON)
    crop_quality: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    detection: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    config_version: Mapped[int] = mapped_column(Integer)
    config_snapshot: Mapped[dict] = mapped_column(JSON)
