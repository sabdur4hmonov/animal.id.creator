from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, Enum, Index, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.species import Species


class MarketRate(Base):
    __tablename__ = "market_rates"
    __table_args__ = (
        CheckConstraint("price_per_kg > 0", name="market_rate_positive"),
        CheckConstraint("basis = 'carcass'", name="market_basis_carcass"),
        Index("ix_market_rates_species_currency_received", "species", "currency", "received_at"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    species: Mapped[Species] = mapped_column(Enum(Species, native_enum=False))
    currency: Mapped[str] = mapped_column(String(3))
    basis: Mapped[str] = mapped_column(String(16))
    price_per_kg: Mapped[Decimal] = mapped_column(Numeric(18, 4))
    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    source: Mapped[str] = mapped_column(String(500))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    operator_id: Mapped[str] = mapped_column(String(100))
