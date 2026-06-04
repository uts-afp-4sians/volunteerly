"""Seed the database with the same fixtures the iOS app mocks.

Mirrors `volunteerly/Core/Networking/MockData.swift` so the live API returns
payloads identical to the mock HTTP client. Idempotent (uses merge on primary
keys) and safe to re-run.

    uv run python scripts/seed.py
"""

import asyncio
from datetime import UTC, datetime

from src.categories.model import Keyword, ProgramCategory
from src.common.enums import ParticipationStatus, ProgramStatus
from src.forum.model import ForumComment, ForumPost
from src.lib.database import Base, async_session_factory, engine
from src.locations.model import Location
from src.programs.model import (
    Program,
    ProgramKeyword,
    ProgramParticipation,
)
from src.users.model import User, UserInterest, UserProfile


def _dt(value: str) -> datetime:
    return datetime.fromisoformat(value)


# Deterministic "created_at" so re-seeding is stable (MockData used `.now`).
CREATED_AT = datetime(2026, 6, 1, 0, 0, 0, tzinfo=UTC)


def _rows() -> list[Base]:
    location = Location(
        location_id=1,
        city="Sydney",
        state_region="NSW",
        country="Australia",
        latitude=-33.8688,
        longitude=151.2093,
    )
    user = User(
        user_id=1,
        email="jane.doe@example.com",
        is_deleted=False,
        deleted_at=None,
        created_at=CREATED_AT,
    )
    user_profile = UserProfile(
        user_id=1,
        first_name="Jane",
        last_name="Doe",
        date_of_birth=_dt("1995-04-20T00:00:00+00:00"),
        profile_image_url="https://i.pravatar.cc/150?img=1",
        occupation="Software Engineer",
        goal_text="I want to give back to my community.",
        location_id=1,
    )
    categories = [
        ProgramCategory(category_id=1, category_name="Environment"),
        ProgramCategory(category_id=2, category_name="Community"),
        ProgramCategory(category_id=3, category_name="Education"),
        ProgramCategory(category_id=4, category_name="Health"),
        ProgramCategory(category_id=5, category_name="Animals"),
        ProgramCategory(category_id=6, category_name="Seniors"),
        ProgramCategory(category_id=7, category_name="Food"),
        ProgramCategory(category_id=8, category_name="Arts"),
    ]
    keywords = [
        Keyword(keyword_id=1, category_id=1, keyword_name="Tree Planting"),
        Keyword(keyword_id=2, category_id=1, keyword_name="Beach Cleanup"),
        Keyword(keyword_id=3, category_id=1, keyword_name="Recycling"),
    ]
    programs = [
        Program(
            program_id=1,
            creator_user_id=1,
            category_id=1,
            location_id=1,
            program_name="Centennial Park Tree Planting",
            description=(
                "Join us for a morning of tree planting in Centennial Park to "
                "restore native bushland."
            ),
            banner_image_url="https://picsum.photos/seed/prog1/800/400",
            start_datetime=_dt("2026-07-01T08:00:00+00:00"),
            end_datetime=_dt("2026-07-01T12:00:00+00:00"),
            max_volunteers=30,
            status=ProgramStatus.OPEN,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
        Program(
            program_id=2,
            creator_user_id=1,
            category_id=1,
            location_id=1,
            program_name="Bondi Beach Cleanup",
            description=(
                "Help keep Bondi Beach clean by joining our monthly cleanup crew."
            ),
            banner_image_url="https://picsum.photos/seed/prog2/800/400",
            start_datetime=_dt("2026-07-15T07:00:00+00:00"),
            end_datetime=_dt("2026-07-15T10:00:00+00:00"),
            max_volunteers=50,
            status=ProgramStatus.OPEN,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
        Program(
            program_id=3,
            creator_user_id=1,
            category_id=3,
            location_id=1,
            program_name="After-School Reading Club",
            description=(
                "Help local primary students build confidence by reading "
                "together once a week."
            ),
            banner_image_url="https://picsum.photos/seed/prog3/800/400",
            start_datetime=_dt("2026-07-08T15:30:00+00:00"),
            end_datetime=_dt("2026-07-08T17:00:00+00:00"),
            max_volunteers=12,
            status=ProgramStatus.OPEN,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
        Program(
            program_id=4,
            creator_user_id=1,
            category_id=6,
            location_id=1,
            program_name="Senior Tech Support Drop-In",
            description=(
                "Spend an afternoon helping seniors get comfortable with their "
                "phones and laptops."
            ),
            banner_image_url="https://picsum.photos/seed/prog4/800/400",
            start_datetime=_dt("2026-07-20T13:00:00+00:00"),
            end_datetime=_dt("2026-07-20T16:00:00+00:00"),
            max_volunteers=8,
            status=ProgramStatus.FULL,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
    ]
    user_interests = [
        UserInterest(user_id=1, keyword_id=1),
        UserInterest(user_id=1, keyword_id=2),
    ]
    program_keywords = [
        ProgramKeyword(program_id=1, keyword_id=1),
        ProgramKeyword(program_id=2, keyword_id=2),
    ]
    participation = ProgramParticipation(
        participation_id=1,
        program_id=1,
        user_id=1,
        participation_status=ParticipationStatus.APPROVED,
        joined_at=CREATED_AT,
    )
    forum_posts = [
        ForumPost(
            post_id=1,
            program_id=1,
            author_user_id=1,
            title="What should I bring?",
            body="Hi everyone, should I bring my own gloves and tools?",
            created_at=CREATED_AT,
        ),
        ForumPost(
            post_id=2,
            program_id=1,
            author_user_id=1,
            title="Parking nearby?",
            body="Is there parking available near the park entrance?",
            created_at=CREATED_AT,
        ),
    ]
    forum_comments = [
        ForumComment(
            comment_id=1,
            post_id=1,
            author_user_id=1,
            body="Yes, please bring gloves! Tools will be provided.",
            created_at=CREATED_AT,
        ),
    ]

    # Dependency order: parents before children.
    return [
        location,
        *categories,
        *keywords,
        user,
        user_profile,
        *programs,
        *user_interests,
        *program_keywords,
        participation,
        *forum_posts,
        *forum_comments,
    ]


async def seed() -> None:
    # Convenience for fresh local dev DBs; no-ops if Alembic already created them.
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session_factory() as session:
        for row in _rows():
            await session.merge(row)
        await session.commit()
    print("Seeded database with MockData fixtures.")


if __name__ == "__main__":
    asyncio.run(seed())
