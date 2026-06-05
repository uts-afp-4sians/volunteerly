"""add program commitment fields

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-06-05 11:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b2c3d4e5f6a7"
down_revision: str | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # SQLite/libSQL can't ALTER in place, so add the columns via batch mode.
    with op.batch_alter_table("programs", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "commitment_frequency",
                sa.Enum("weekly", "monthly", name="commitmentfrequency"),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column(
                "commitment_duration",
                sa.Enum(
                    "under_2",
                    "three_to_six",
                    "seven_to_nine",
                    "continuous",
                    name="commitmentduration",
                ),
                nullable=True,
            )
        )


def downgrade() -> None:
    with op.batch_alter_table("programs", schema=None) as batch_op:
        batch_op.drop_column("commitment_duration")
        batch_op.drop_column("commitment_frequency")
