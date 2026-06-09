from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column

from src.common.enums import (
    CommitmentDuration,
    CommitmentFrequency,
    ParticipationStatus,
    ProgramStatus,
)
from src.lib.database import Base


class Program(Base):
    """A volunteering program (PROGRAM)."""

    __tablename__ = "programs"

    program_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    creator_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id"), index=True
    )
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.category_id"), index=True
    )
    location_id: Mapped[int] = mapped_column(
        ForeignKey("locations.location_id"), index=True
    )
    program_name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str] = mapped_column(Text)
    banner_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    start_datetime: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_datetime: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    max_volunteers: Mapped[int] = mapped_column(Integer)
    commitment_frequency: Mapped[CommitmentFrequency | None] = mapped_column(
        SAEnum(CommitmentFrequency, values_callable=lambda e: [m.value for m in e]),
        nullable=True,
    )
    commitment_duration: Mapped[CommitmentDuration | None] = mapped_column(
        SAEnum(CommitmentDuration, values_callable=lambda e: [m.value for m in e]),
        nullable=True,
    )
    status: Mapped[ProgramStatus] = mapped_column(
        SAEnum(ProgramStatus, values_callable=lambda e: [m.value for m in e]),
        default=ProgramStatus.DRAFT,
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ProgramKeyword(Base):
    """Junction tagging a program with a keyword (PROGRAM_KEYWORD)."""

    __tablename__ = "program_keywords"

    program_id: Mapped[int] = mapped_column(
        ForeignKey("programs.program_id"), primary_key=True
    )
    keyword_id: Mapped[int] = mapped_column(
        ForeignKey("keywords.keyword_id"), primary_key=True
    )


class ProgramParticipation(Base):
    """A user's participation in a program (PROGRAM_PARTICIPATION)."""

    __tablename__ = "program_participations"

    participation_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    program_id: Mapped[int] = mapped_column(
        ForeignKey("programs.program_id"), index=True
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), index=True)
    participation_status: Mapped[ParticipationStatus] = mapped_column(
        SAEnum(ParticipationStatus, values_callable=lambda e: [m.value for m in e]),
        default=ParticipationStatus.PENDING,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ProgramBookmark(Base):
    """Junction: a program a user bookmarked (PROGRAM_BOOKMARK)."""

    __tablename__ = "program_bookmarks"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), primary_key=True)
    program_id: Mapped[int] = mapped_column(
        ForeignKey("programs.program_id"), primary_key=True
    )
    bookmarked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
