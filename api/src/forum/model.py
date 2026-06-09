from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from src.lib.database import Base


class ForumPost(Base):
    """A forum post attached to a program (FORUM_POST)."""

    __tablename__ = "forum_posts"

    post_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    program_id: Mapped[int] = mapped_column(
        ForeignKey("programs.program_id"), index=True
    )
    author_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ForumComment(Base):
    """A comment on a forum post (FORUM_COMMENT).

    ``parent_comment_id`` is a self-referential FK: ``None`` for a top-level
    comment, otherwise the id of the comment it replies to. This drives the
    threaded conversation on the iOS forum screen.
    """

    __tablename__ = "forum_comments"

    comment_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("forum_posts.post_id"), index=True)
    author_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), index=True)
    parent_comment_id: Mapped[int | None] = mapped_column(
        ForeignKey("forum_comments.comment_id"), nullable=True, index=True
    )
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ForumCommentLike(Base):
    """A user's like on a forum comment (FORUM_COMMENT_LIKE).

    The composite primary key ``(comment_id, user_id)`` makes a like idempotent
    — a user can like a comment at most once — and lets ``like_count`` stay a
    cheap aggregate over rows rather than a counter column that can drift.
    """

    __tablename__ = "forum_comment_likes"

    comment_id: Mapped[int] = mapped_column(
        ForeignKey("forum_comments.comment_id"), primary_key=True
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id"), primary_key=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
