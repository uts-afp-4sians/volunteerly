"""user_interests reference categories

Interests and program categories were one taxonomy stored twice: keywords
flagged ``is_interest`` mirrored the categories table 1:1 (same ids, same
names), and ``user_interests`` pointed at the keyword copy. This collapses the
duplication: ``user_interests.keyword_id`` becomes ``category_id`` (FK to
``categories``), mapped through each keyword's parent category, and the
``is_interest`` flag is dropped.

Revision ID: c9d0e1f2a3b4
Revises: b8c9d0e1f2a3
Create Date: 2026-06-11 18:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c9d0e1f2a3b4"
down_revision: str | None = "b8c9d0e1f2a3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # SQLite/libSQL can't rewrite an FK in place — rebuild the junction. The
    # copy maps each interest keyword to its parent category; INSERT OR IGNORE
    # collapses any two keywords that share a category into one interest row.
    op.create_table(
        "user_interests_new",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("category_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.user_id"]),
        sa.ForeignKeyConstraint(["category_id"], ["categories.category_id"]),
        sa.PrimaryKeyConstraint("user_id", "category_id"),
    )
    op.execute(
        """
        INSERT OR IGNORE INTO user_interests_new (user_id, category_id)
        SELECT ui.user_id, k.category_id
        FROM user_interests ui
        JOIN keywords k ON k.keyword_id = ui.keyword_id
        """
    )
    op.drop_table("user_interests")
    op.rename_table("user_interests_new", "user_interests")

    with op.batch_alter_table("keywords", schema=None) as batch_op:
        batch_op.drop_column("is_interest")


def downgrade() -> None:
    with op.batch_alter_table("keywords", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "is_interest",
                sa.Boolean(),
                nullable=False,
                server_default="0",
            )
        )
    # Re-flag one keyword per category as the interest mirror (lowest id wins),
    # then point user_interests back at those keywords.
    op.execute(
        """
        UPDATE keywords SET is_interest = 1
        WHERE keyword_id IN (
            SELECT MIN(keyword_id) FROM keywords GROUP BY category_id
        )
        """
    )
    op.create_table(
        "user_interests_old",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("keyword_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.user_id"]),
        sa.ForeignKeyConstraint(["keyword_id"], ["keywords.keyword_id"]),
        sa.PrimaryKeyConstraint("user_id", "keyword_id"),
    )
    op.execute(
        """
        INSERT OR IGNORE INTO user_interests_old (user_id, keyword_id)
        SELECT ui.user_id, (
            SELECT MIN(k.keyword_id) FROM keywords k
            WHERE k.category_id = ui.category_id
        )
        FROM user_interests ui
        """
    )
    op.drop_table("user_interests")
    op.rename_table("user_interests_old", "user_interests")
