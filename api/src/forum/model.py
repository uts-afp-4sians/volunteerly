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
    author_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id"), index=True
    )
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ForumComment(Base):
    """A comment on a forum post (FORUM_COMMENT)."""

    __tablename__ = "forum_comments"

    comment_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    post_id: Mapped[int] = mapped_column(
        ForeignKey("forum_posts.post_id"), index=True
    )
    author_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id"), index=True
    )
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
