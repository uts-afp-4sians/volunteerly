"""add keyword is_interest

Revision ID: f5a6b7c8d9e0
Revises: e4f5a6b7c8d9
Create Date: 2026-06-09 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f5a6b7c8d9e0"
down_revision: str | None = "e4f5a6b7c8d9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # SQLite/libSQL can't ALTER in place, so add the column via batch mode.
    # server_default keeps existing rows valid; the model default applies to
    # new inserts.
    with op.batch_alter_table("keywords", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "is_interest",
                sa.Boolean(),
                nullable=False,
                server_default="0",
            )
        )


def downgrade() -> None:
    with op.batch_alter_table("keywords", schema=None) as batch_op:
        batch_op.drop_column("is_interest")
