"""Append-only market quote history; no defaults or invented current prices."""

import sqlalchemy as sa

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "market_rates",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("species", sa.String(6), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("basis", sa.String(16), nullable=False),
        sa.Column("price_per_kg", sa.Numeric(18, 4), nullable=False),
        sa.Column("observed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source", sa.String(500), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("operator_id", sa.String(100), nullable=False),
        sa.CheckConstraint("price_per_kg > 0", name="market_rate_positive"),
        sa.CheckConstraint("basis = 'carcass'", name="market_basis_carcass"),
    )
    op.create_index(
        "ix_market_rates_species_currency_received", "market_rates", ["species", "currency", "received_at"]
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute("""CREATE TRIGGER market_rates_append_only BEFORE UPDATE OR DELETE ON market_rates
                      FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()""")
    else:
        for action in ("update", "delete"):
            op.execute(f"""CREATE TRIGGER market_rates_no_{action} BEFORE {action} ON market_rates
                           BEGIN SELECT RAISE(ABORT, 'Evidence is append-only'); END""")


def downgrade():
    op.drop_index("ix_market_rates_species_currency_received", table_name="market_rates")
    op.drop_table("market_rates")
