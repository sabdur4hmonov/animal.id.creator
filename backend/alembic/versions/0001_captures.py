"""Capture metadata and species-aware collection provenance."""

import sqlalchemy as sa

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "captures",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("animal_id", sa.String(64), nullable=False),
        sa.Column(
            "species",
            sa.Enum("cattle", "sheep", name="species", native_enum=False, create_constraint=True),
            nullable=False,
        ),
        sa.Column("gps", sa.JSON(), nullable=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("operator_id", sa.String(100), nullable=False),
        sa.Column("image_quality_score", sa.Float(), nullable=False),
        sa.Column("file_path", sa.String(512), nullable=False),
        sa.Column("crop_path", sa.String(512), nullable=True),
        sa.Column("crop_status", sa.String(32), nullable=False),
        sa.Column("quality", sa.JSON(), nullable=False),
        sa.Column("crop_quality", sa.JSON(), nullable=True),
        sa.Column("detection", sa.JSON(), nullable=True),
        sa.Column("config_version", sa.Integer(), nullable=False),
        sa.Column("config_snapshot", sa.JSON(), nullable=False),
        sa.CheckConstraint("image_quality_score >= 0 AND image_quality_score <= 1", name="quality_range"),
        sa.CheckConstraint("crop_status IN ('pending_model', 'cropped')", name="crop_status_values"),
    )
    op.create_index("ix_captures_species_animal_timestamp", "captures", ["species", "animal_id", "timestamp"])


def downgrade():
    op.drop_index("ix_captures_species_animal_timestamp", table_name="captures")
    op.drop_table("captures")
