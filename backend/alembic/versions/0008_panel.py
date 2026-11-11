"""Add private browser sessions and immutable mobile profile summaries.

Compact summaries allow bank/vet pages to show explicitly synchronized mobile
weights and tags without uploading megabytes of raw depth or rewriting scans.
"""

import sqlalchemy as sa

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "browser_sessions",
        sa.Column("token_sha256", sa.String(64), primary_key=True),
        sa.Column("credential_sha256", sa.String(64), nullable=False),
        sa.Column("operator_id", sa.String(100), nullable=False),
        sa.Column("csrf", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_browser_sessions_expires_at", "browser_sessions", ["expires_at"])
    op.create_table(
        "field_summaries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("species", sa.String(6), nullable=False),
        sa.Column("animal_id", sa.String(64), nullable=False),
        sa.Column("actor_id", sa.String(100), nullable=False),
        sa.Column("local_event_key", sa.String(32), nullable=False),
        sa.Column("observed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        sa.UniqueConstraint("actor_id", "local_event_key", name="field_summary_local_unique"),
    )
    for field in ("species", "animal_id"):
        op.create_index("ix_field_summaries_" + field, "field_summaries", [field])
    if op.get_bind().dialect.name == "postgresql":
        op.execute(
            "CREATE TRIGGER field_summaries_append_only BEFORE UPDATE OR DELETE ON field_summaries FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()"
        )
    else:
        for action in ("update", "delete"):
            op.execute(
                f"CREATE TRIGGER field_summaries_no_{action} BEFORE {action} ON field_summaries BEGIN SELECT RAISE(ABORT,'Evidence is append-only'); END"
            )


def downgrade():
    op.drop_table("field_summaries")
    op.drop_table("browser_sessions")
