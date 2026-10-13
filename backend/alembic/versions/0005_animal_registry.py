"""Add non-recycled numbering and ownership/lifecycle projection without rewriting scans."""

import sqlalchemy as sa

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "animal_number_counters",
        sa.Column("prefix", sa.String(8), primary_key=True),
        sa.Column("last_number", sa.BigInteger(), nullable=False),
        sa.CheckConstraint("last_number >= 1", name="animal_counter_positive"),
    )
    op.create_table(
        "animal_profiles",
        sa.Column("species", sa.String(6), primary_key=True),
        sa.Column("animal_id", sa.String(64), primary_key=True),
        sa.Column("numbered_id", sa.String(64), nullable=True, unique=True),
        sa.Column("lifecycle", sa.String(16), nullable=False),
        sa.Column("owner", sa.JSON(), nullable=True),
        sa.Column("retired_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["species", "animal_id"], ["animals.species", "animals.animal_id"]),
        sa.CheckConstraint(
            "lifecycle IN ('active', 'deceased', 'slaughtered')", name="animal_lifecycle_values"
        ),
    )
    op.create_table(
        "registry_receipts",
        sa.Column("operator_id", sa.String(100), primary_key=True),
        sa.Column("request_key", sa.String(128), primary_key=True),
        sa.Column("payload_sha256", sa.String(64), nullable=False),
        sa.Column("response", sa.JSON(), nullable=False),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute(
            "CREATE TRIGGER registry_receipts_append_only BEFORE UPDATE OR DELETE ON registry_receipts FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()"
        )
        op.execute(
            "CREATE TRIGGER animal_profiles_no_delete BEFORE DELETE ON animal_profiles FOR EACH ROW EXECUTE FUNCTION reject_evidence_change()"
        )
        op.execute("""CREATE FUNCTION protect_animal_counter() RETURNS trigger AS $$ BEGIN
            IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'Animal numbers cannot be recycled'; END IF;
            IF NEW.prefix <> OLD.prefix OR NEW.last_number <= OLD.last_number THEN
                RAISE EXCEPTION 'Animal numbers must advance'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql""")
        op.execute(
            "CREATE TRIGGER animal_counter_forward BEFORE UPDATE OR DELETE ON animal_number_counters FOR EACH ROW EXECUTE FUNCTION protect_animal_counter()"
        )
        op.execute("""CREATE FUNCTION protect_animal_profile() RETURNS trigger AS $$ BEGIN
            IF OLD.lifecycle <> 'active' OR NEW.species <> OLD.species OR NEW.animal_id <> OLD.animal_id
                OR NEW.numbered_id IS DISTINCT FROM OLD.numbered_id THEN
                RAISE EXCEPTION 'Animal identity and archived history are retained'; END IF;
            RETURN NEW; END; $$ LANGUAGE plpgsql""")
        op.execute(
            "CREATE TRIGGER animal_profile_identity BEFORE UPDATE ON animal_profiles FOR EACH ROW EXECUTE FUNCTION protect_animal_profile()"
        )
    else:
        for action in ("update", "delete"):
            op.execute(
                f"CREATE TRIGGER registry_receipts_no_{action} BEFORE {action} ON registry_receipts BEGIN SELECT RAISE(ABORT, 'Evidence is append-only'); END"
            )
        op.execute(
            "CREATE TRIGGER animal_profiles_no_delete BEFORE DELETE ON animal_profiles BEGIN SELECT RAISE(ABORT, 'Animal history is retained'); END"
        )
        op.execute(
            "CREATE TRIGGER animal_counter_no_delete BEFORE DELETE ON animal_number_counters BEGIN SELECT RAISE(ABORT, 'Animal numbers cannot be recycled'); END"
        )
        op.execute(
            "CREATE TRIGGER animal_counter_forward BEFORE UPDATE ON animal_number_counters WHEN NEW.prefix != OLD.prefix OR NEW.last_number <= OLD.last_number BEGIN SELECT RAISE(ABORT, 'Animal numbers must advance'); END"
        )
        op.execute(
            "CREATE TRIGGER animal_profile_identity BEFORE UPDATE ON animal_profiles WHEN OLD.lifecycle != 'active' OR NEW.species != OLD.species OR NEW.animal_id != OLD.animal_id OR NEW.numbered_id IS NOT OLD.numbered_id BEGIN SELECT RAISE(ABORT, 'Animal identity and archived history are retained'); END"
        )


def downgrade():
    for table in ("registry_receipts", "animal_profiles", "animal_number_counters"):
        op.drop_table(table)
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP FUNCTION protect_animal_counter()")
        op.execute("DROP FUNCTION protect_animal_profile()")
