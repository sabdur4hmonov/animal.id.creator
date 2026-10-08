from sqlalchemy import create_engine, pool

from alembic import context
from app.core.database import Base
from app.core.settings import get_settings
from app.models.business import Animal, AuditEvent, DuplicateCase  # noqa: F401
from app.models.capture import Capture  # noqa: F401
from app.models.upload_receipt import UploadReceipt  # noqa: F401
from app.models.valuation import MarketRate  # noqa: F401

target_metadata = Base.metadata
url = get_settings().database_url

if context.is_offline_mode():
    context.configure(
        url=url, target_metadata=target_metadata, literal_binds=True, dialect_opts={"paramstyle": "named"}
    )
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = create_engine(url, poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
