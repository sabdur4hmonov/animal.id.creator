"""Add registration/review tables and immutable scan provenance; preserve legacy rows."""

import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def protect_table(table):
    if op.get_bind().dialect.name == "postgresql":
        op.execute(f"""CREATE TRIGGER {table}_append_only BEFORE UPDATE OR DELETE ON {table}
                      FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()""")
    else:
        for action in ("UPDATE", "DELETE"):
            op.execute(f"""CREATE TRIGGER {table}_no_{action.lower()} BEFORE {action} ON {table}
                           BEGIN SELECT RAISE(ABORT, 'Evidence is append-only'); END""")


def upgrade():
    for column in (
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_sha256", sa.String(64), nullable=True),
        sa.Column("pixel_sha256", sa.String(64), nullable=True),
        sa.Column("stored_sha256", sa.String(64), nullable=True),
        sa.Column("risk_signals", sa.JSON(), nullable=True),
        sa.Column("duplicate_summary", sa.JSON(), nullable=True),
    ):
        op.add_column("captures", column)
    op.create_index("ix_captures_species_pixel_sha256", "captures", ["species", "pixel_sha256"])
    op.create_table(
        "animals",
        sa.Column("species", sa.String(6), primary_key=True),
        sa.Column("animal_id", sa.String(64), primary_key=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("registered_by", sa.String(100), nullable=True),
        sa.CheckConstraint("status IN ('open', 'insured', 'collateral')", name="animal_status_values"),
        sa.CheckConstraint("version >= 1", name="animal_version_positive"),
    )
    # Migration time is when legacy collection labels enter the registry, not scan time.
    op.execute("""INSERT INTO animals (species, animal_id, status, version, created_at)
                  SELECT DISTINCT species, animal_id, 'open', 1, CURRENT_TIMESTAMP FROM captures""")
    op.create_table(
        "audit_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("species", sa.String(6), nullable=False),
        sa.Column("animal_id", sa.String(64), nullable=False),
        sa.Column("action", sa.String(64), nullable=False),
        sa.Column("actor_id", sa.String(100), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
    )
    op.create_table(
        "duplicate_cases",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("species", sa.String(6), nullable=False),
        sa.Column("animal_id", sa.String(64), nullable=False),
        sa.Column("capture_id", sa.String(36), sa.ForeignKey("captures.id"), nullable=False),
        sa.Column("matched_capture_id", sa.String(36), sa.ForeignKey("captures.id"), nullable=True),
        sa.Column("reason", sa.String(64), nullable=False),
        sa.Column("state", sa.String(16), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewed_by", sa.String(100), nullable=True),
        sa.Column("review_note", sa.String(1000), nullable=True),
        sa.UniqueConstraint("capture_id", "matched_capture_id", name="duplicate_pair_unique"),
        sa.CheckConstraint("state IN ('pending', 'confirmed', 'dismissed')", name="duplicate_state_values"),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute("""CREATE FUNCTION reject_evidence_change() RETURNS trigger AS $$
                      BEGIN RAISE EXCEPTION 'Evidence is append-only'; END;
                      $$ LANGUAGE plpgsql""")
    for table in ("captures", "audit_events"):
        protect_table(table)


def downgrade():
    for table in ("captures", "audit_events"):
        if op.get_bind().dialect.name == "postgresql":
            op.execute(f"DROP TRIGGER {table}_append_only ON {table}")
        else:
            for action in ("update", "delete"):
                op.execute(f"DROP TRIGGER {table}_no_{action}")
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP FUNCTION reject_evidence_change()")
    for table in ("duplicate_cases", "audit_events", "animals"):
        op.drop_table(table)
    op.drop_index("ix_captures_species_pixel_sha256", table_name="captures")
    with op.batch_alter_table("captures") as batch:
        for column in (
            "received_at",
            "source_sha256",
            "pixel_sha256",
            "stored_sha256",
            "risk_signals",
            "duplicate_summary",
        ):
            batch.drop_column(column)
