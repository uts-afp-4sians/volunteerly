"""add user profile bio, instagram, key_skills

Revision ID: e4f5a6b7c8d9
Revises: c3d4e5f6a7b8
Create Date: 2026-06-09 11:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e4f5a6b7c8d9"
down_revision: str | None = "c3d4e5f6a7b8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # SQLite/libSQL can't ALTER in place, so add the columns via batch mode.
    with op.batch_alter_table("user_profiles", schema=None) as batch_op:
        batch_op.add_column(sa.Column("bio", sa.String(length=1000), nullable=True))
        batch_op.add_column(
            sa.Column("instagram", sa.String(length=255), nullable=True)
        )
        batch_op.add_column(
            sa.Column("key_skills", sa.String(length=500), nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("user_profiles", schema=None) as batch_op:
        batch_op.drop_column("key_skills")
        batch_op.drop_column("instagram")
        batch_op.drop_column("bio")
