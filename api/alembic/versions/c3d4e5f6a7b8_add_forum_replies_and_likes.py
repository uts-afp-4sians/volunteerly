"""add forum comment replies and likes

Adds threaded replies (``forum_comments.parent_comment_id``) and a
``forum_comment_likes`` junction table.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-06-06 16:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c3d4e5f6a7b8"
down_revision: str | None = "b2c3d4e5f6a7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Self-referential reply pointer on comments. SQLite/libSQL can't ALTER in
    # place, so add the column (with its FK) via batch mode, then index it.
    with op.batch_alter_table("forum_comments", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "parent_comment_id",
                sa.Integer(),
                sa.ForeignKey(
                    "forum_comments.comment_id",
                    name=op.f("fk_forum_comments_parent_comment_id_forum_comments"),
                ),
                nullable=True,
            )
        )
        batch_op.create_index(
            batch_op.f("ix_forum_comments_parent_comment_id"),
            ["parent_comment_id"],
            unique=False,
        )

    # Like junction. Composite PK (comment_id, user_id) keeps likes idempotent.
    op.create_table(
        "forum_comment_likes",
        sa.Column("comment_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["comment_id"],
            ["forum_comments.comment_id"],
            name=op.f("fk_forum_comment_likes_comment_id_forum_comments"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name=op.f("fk_forum_comment_likes_user_id_users"),
        ),
        sa.PrimaryKeyConstraint(
            "comment_id", "user_id", name=op.f("pk_forum_comment_likes")
        ),
    )
    with op.batch_alter_table("forum_comment_likes", schema=None) as batch_op:
        batch_op.create_index(
            batch_op.f("ix_forum_comment_likes_user_id"),
            ["user_id"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("forum_comment_likes", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_forum_comment_likes_user_id"))
    op.drop_table("forum_comment_likes")

    with op.batch_alter_table("forum_comments", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_forum_comments_parent_comment_id"))
        batch_op.drop_column("parent_comment_id")
