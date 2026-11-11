"""Add revocable public slaughter codes and shared rate counters."""

import sqlalchemy as sa

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "slaughter_codes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("species", sa.String(6), nullable=False),
        sa.Column("animal_id", sa.String(64), nullable=False),
        sa.Column("token_sha256", sa.String(64), unique=True, nullable=False),
        sa.Column("issued_by", sa.String(100), nullable=False),
        sa.Column("request_key", sa.String(128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
    )
    op.create_index("slaughter_codes_animal", "slaughter_codes", ["species", "animal_id"])
    op.create_table(
        "code_revocations",
        sa.Column("code_id", sa.String(36), sa.ForeignKey("slaughter_codes.id"), primary_key=True),
        sa.Column("actor_id", sa.String(100), nullable=False),
        sa.Column("reason", sa.String(1000), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "rate_windows",
        sa.Column("scope_key", sa.String(64), primary_key=True),
        sa.Column("window_start", sa.BigInteger(), primary_key=True),
        sa.Column("hits", sa.Integer(), nullable=False),
    )
    for table in ("slaughter_codes", "code_revocations"):
        if op.get_bind().dialect.name == "postgresql":
            op.execute(
                f"CREATE TRIGGER {table}_append_only BEFORE UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()"
            )
        else:
            for action in ("update", "delete"):
                op.execute(
                    f"CREATE TRIGGER {table}_no_{action} BEFORE {action} ON {table} BEGIN SELECT RAISE(ABORT, 'Evidence is append-only'); END"
                )


def downgrade():
    for table in ("rate_windows", "code_revocations", "slaughter_codes"):
        op.drop_table(table)
