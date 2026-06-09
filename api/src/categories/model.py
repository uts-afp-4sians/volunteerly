from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from src.lib.database import Base


class ProgramCategory(Base):
    """A program category (CATEGORY)."""

    __tablename__ = "categories"

    category_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category_name: Mapped[str] = mapped_column(String(255))


class Keyword(Base):
    """A keyword belonging to a category (KEYWORD)."""

    __tablename__ = "keywords"

    keyword_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.category_id"), index=True
    )
    keyword_name: Mapped[str] = mapped_column(String(255))
    # Marks the keyword as a profile-interest chip (the signup / "My interests"
    # picker), distinguishing it from program-tagging keywords.
    is_interest: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="0"
    )
