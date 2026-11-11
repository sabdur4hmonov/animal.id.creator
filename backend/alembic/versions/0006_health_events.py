"""Add immutable health history without rewriting collection/registry data."""

import sqlalchemy as sa

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "health_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("species", sa.String(6), nullable=False),
        sa.Column("animal_id", sa.String(64), nullable=False),
        sa.Column("local_event_key", sa.String(32), nullable=False),
        sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("event_date", sa.Date(), nullable=False),
        sa.Column("description", sa.String(500), nullable=False),
        sa.Column("veterinarian_name", sa.String(120), nullable=True),
        sa.Column("notes", sa.String(1000), nullable=False),
        sa.Column("correction_of", sa.String(36), sa.ForeignKey("health_events.id"), nullable=True),
        sa.Column("actor_id", sa.String(100), nullable=False),
        sa.Column("actor_role", sa.String(24), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        sa.UniqueConstraint("correction_of", name="health_single_successor"),
        sa.UniqueConstraint("actor_id", "local_event_key", name="health_client_event_unique"),
    )
    op.create_index("health_animal_date", "health_events", ["species", "animal_id", "event_date"])
    if op.get_bind().dialect.name == "postgresql":
        op.execute(
            "CREATE TRIGGER health_events_append_only BEFORE UPDATE OR DELETE ON health_events FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()"
        )
    else:
        for action in ("update", "delete"):
            op.execute(
                f"CREATE TRIGGER health_events_no_{action} BEFORE {action} ON health_events BEGIN SELECT RAISE(ABORT, 'Evidence is append-only'); END"
            )


def downgrade():
    op.drop_table("health_events")
