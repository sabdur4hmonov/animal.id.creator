"""Add password users and immutable access-policy audit; bearer keys are preserved."""

import sqlalchemy as sa

from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "user_accounts",
        sa.Column("username", sa.String(64), primary_key=True),
        sa.Column("operator_id", sa.String(100), unique=True, nullable=False),
        sa.Column("role", sa.String(24), nullable=False),
        sa.Column("password_hash", sa.String(512), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("disabled_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "role IN ('admin','operator','veterinar','bank_viewer','bank_officer')",
            name="account_role_values",
        ),
    )
    op.create_table(
        "access_audit",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("actor_id", sa.String(100), nullable=False),
        sa.Column("subject", sa.String(100), nullable=False),
        sa.Column("action", sa.String(32), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute(
            "CREATE TRIGGER access_audit_append_only BEFORE UPDATE OR DELETE ON access_audit FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()"
        )
    else:
        for action in ("update", "delete"):
            op.execute(
                f"CREATE TRIGGER access_audit_no_{action} BEFORE {action} ON access_audit BEGIN SELECT RAISE(ABORT,'Evidence is append-only'); END"
            )


def downgrade():
    op.drop_table("access_audit")
    op.drop_table("user_accounts")
