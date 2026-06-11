from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from src.lib.database import Base


class ProgramCategory(Base):
    """A program category (CATEGORY) — the single taxonomy.

    Also the catalog behind profile interests (USER_INTEREST references it
    directly); there is no separate interest table or flag.
    """

    __tablename__ = "categories"

    category_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category_name: Mapped[str] = mapped_column(String(255))


class Keyword(Base):
    """A program-tagging keyword belonging to a category (KEYWORD)."""

    __tablename__ = "keywords"

    keyword_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.category_id"), index=True
    )
    keyword_name: Mapped[str] = mapped_column(String(255))
