from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from src.lib.database import Base


class User(Base):
    """A user account (USER)."""

    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    # bcrypt hash. Nullable so non-password identities (future OAuth/SSO) and
    # legacy rows remain valid; never serialized in any response schema.
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class UserProfile(Base):
    """Extended profile for a user (USER_PROFILE)."""

    __tablename__ = "user_profiles"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), primary_key=True)
    first_name: Mapped[str] = mapped_column(String(255))
    last_name: Mapped[str] = mapped_column(String(255))
    # iOS decodes this as a full ISO8601 datetime, so store it as a datetime.
    date_of_birth: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    profile_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    occupation: Mapped[str | None] = mapped_column(String(255), nullable=True)
    goal_text: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    # Free-text "My bio" shown on the profile screen.
    bio: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    # Instagram handle for "send me the messages"; stored without the leading
    # '@' (the client renders the prefix).
    instagram: Mapped[str | None] = mapped_column(String(255), nullable=True)
    key_skills: Mapped[str | None] = mapped_column(String(500), nullable=True)
    location_id: Mapped[int | None] = mapped_column(
        ForeignKey("locations.location_id"), nullable=True
    )


class UserInterest(Base):
    """Junction: a category the user is interested in (USER_INTEREST).

    Interests and program categories are one taxonomy — this references
    ``categories`` directly (the old keyword mirror was removed).
    """

    __tablename__ = "user_interests"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), primary_key=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.category_id"), primary_key=True
    )
