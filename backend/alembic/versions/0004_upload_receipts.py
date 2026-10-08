"""Add upload replay receipts without modifying existing scan evidence."""

import sqlalchemy as sa

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "upload_receipts",
        sa.Column("operator_id", sa.String(100), primary_key=True),
        sa.Column("request_key", sa.String(128), primary_key=True),
        sa.Column("payload_sha256", sa.String(64), nullable=False),
        sa.Column("capture_id", sa.String(36), sa.ForeignKey("captures.id"), nullable=False),
        sa.Column("response", sa.JSON(), nullable=False),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute("""CREATE TRIGGER upload_receipts_append_only BEFORE UPDATE OR DELETE ON upload_receipts
                      FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()""")
    else:
        for action in ("update", "delete"):
            op.execute(f"""CREATE TRIGGER upload_receipts_no_{action} BEFORE {action} ON upload_receipts
                           BEGIN SELECT RAISE(ABORT, 'Evidence is append-only'); END""")


def downgrade():
    op.drop_table("upload_receipts")
