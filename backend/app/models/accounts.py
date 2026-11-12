"""Pilot accounts are mutable access policy; their changes have an immutable audit."""

from datetime import datetime

from sqlalchemy import JSON, CheckConstraint, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserAccount(Base):
    __tablename__ = "user_accounts"
    __table_args__ = (
        CheckConstraint(
            "role IN ('admin','operator','veterinar','bank_viewer','bank_officer')",
            name="account_role_values",
        ),
    )
    username: Mapped[str] = mapped_column(String(64), primary_key=True)
    operator_id: Mapped[str] = mapped_column(String(100), unique=True)
    role: Mapped[str] = mapped_column(String(24))
    password_hash: Mapped[str] = mapped_column(String(512))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    disabled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class AccessAudit(Base):
    __tablename__ = "access_audit"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    actor_id: Mapped[str] = mapped_column(String(100))
    subject: Mapped[str] = mapped_column(String(100))
    action: Mapped[str] = mapped_column(String(32))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    details: Mapped[dict] = mapped_column(JSON)
