"""add program_images gallery table

Revision ID: a7b8c9d0e1f2
Revises: f5a6b7c8d9e0
Create Date: 2026-06-10 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a7b8c9d0e1f2"
down_revision: str | None = "f5a6b7c8d9e0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "program_images",
        sa.Column("image_id", sa.Integer(), nullable=False),
        sa.Column("program_id", sa.Integer(), nullable=False),
        sa.Column("image_url", sa.String(length=500), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["program_id"], ["programs.program_id"]),
        sa.PrimaryKeyConstraint("image_id"),
    )
    op.create_index(
        op.f("ix_program_images_program_id"),
        "program_images",
        ["program_id"],
        unique=False,
    )

    # Backfill: every existing program with a single banner becomes its first
    # gallery image (sort_order 0), so the new ordered read is consistent with
    # the legacy column from day one.
    op.execute(
        """
        INSERT INTO program_images (program_id, image_url, sort_order)
        SELECT program_id, banner_image_url, 0
        FROM programs
        WHERE banner_image_url IS NOT NULL AND banner_image_url <> ''
        """
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_program_images_program_id"), table_name="program_images"
    )
    op.drop_table("program_images")
