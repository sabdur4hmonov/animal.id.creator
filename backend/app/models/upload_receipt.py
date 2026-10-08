from sqlalchemy import JSON, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UploadReceipt(Base):
    """Committed response associated with one operator's immutable request."""

    __tablename__ = "upload_receipts"

    operator_id: Mapped[str] = mapped_column(String(100), primary_key=True)
    request_key: Mapped[str] = mapped_column(String(128), primary_key=True)
    payload_sha256: Mapped[str] = mapped_column(String(64))
    capture_id: Mapped[str] = mapped_column(ForeignKey("captures.id"))
    response: Mapped[dict] = mapped_column(JSON)
