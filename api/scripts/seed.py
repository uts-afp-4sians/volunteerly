"""Seed the database with the same fixtures the iOS app mocks.

Mirrors `volunteerly/Core/Networking/MockData.swift` so the live API returns
payloads identical to the mock HTTP client. Idempotent (uses merge on primary
keys) and safe to re-run.

    uv run python scripts/seed.py
"""

from datetime import UTC, datetime

from src.auth.security import hash_password
from src.categories.model import Keyword, ProgramCategory
from src.common.enums import (
    CommitmentDuration,
    CommitmentFrequency,
    ParticipationStatus,
    ProgramStatus,
)
from src.forum.model import ForumComment, ForumCommentLike, ForumPost
from src.lib.database import Base, engine, session_factory
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
    # Distinct Sydney-area spots so each program sits at its own coordinates and
    # the list can show a meaningful per-card distance (not all the same point).
    locations = [
        Location(
            location_id=1,
            city="Sydney",
            state_region="NSW",
            country="Australia",
            latitude=-33.8688,
            longitude=151.2093,
        ),
        Location(
            location_id=2,
            city="Bondi Beach",
            state_region="NSW",
            country="Australia",
            latitude=-33.8908,
            longitude=151.2743,
        ),
        Location(
            location_id=3,
            city="Newtown",
            state_region="NSW",
            country="Australia",
            latitude=-33.8983,
            longitude=151.1784,
        ),
        Location(
            location_id=4,
            city="Chatswood",
            state_region="NSW",
            country="Australia",
            latitude=-33.7969,
            longitude=151.1803,
        ),
    ]
    user = User(
        user_id=1,
        email="jane.doe@example.com",
        # Demo credential: jane.doe@example.com / "password123".
        password_hash=hash_password("password123"),
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
    # A few extra members so the Member board / forum thread show varied
    # authors and the Author A-Z / Z-A sort chips have something to do.
    # Mirrors `MockData.memberProfiles` in the iOS app.
    members = [
        (2, "Marcus", "Lee", "https://i.pravatar.cc/150?img=12", "Teacher"),
        (3, "Aisha", "Khan", "https://i.pravatar.cc/150?img=5", "Nurse"),
        (4, "Tom", "Becker", "https://i.pravatar.cc/150?img=15", "Designer"),
    ]
    member_users = [
        User(
            user_id=uid,
            email=f"{first.lower()}.{last.lower()}@example.com",
            password_hash=hash_password("password123"),
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        )
        for uid, first, last, _img, _occ in members
    ]
    member_profiles = [
        UserProfile(
            user_id=uid,
            first_name=first,
            last_name=last,
            date_of_birth=None,
            profile_image_url=img,
            occupation=occ,
            goal_text=None,
            location_id=1,
        )
        for uid, first, last, img, occ in members
    ]
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
        # Program-tagging keywords (referenced by program_keywords below).
        Keyword(keyword_id=1, category_id=1, keyword_name="Tree Planting"),
        Keyword(keyword_id=2, category_id=1, keyword_name="Beach Cleanup"),
        Keyword(keyword_id=3, category_id=1, keyword_name="Recycling"),
        # Profile interest catalog — the chips on the "My interests" picker.
        # Each maps to the closest existing category (the category isn't shown
        # in the interest UI; emoji are rendered client-side by keyword name).
        Keyword(keyword_id=4, category_id=5, keyword_name="Animal Care"),
        Keyword(keyword_id=5, category_id=8, keyword_name="Arts & Creativity"),
        Keyword(keyword_id=6, category_id=2, keyword_name="Community Building"),
        Keyword(keyword_id=7, category_id=3, keyword_name="Education"),
        Keyword(keyword_id=8, category_id=6, keyword_name="Aged Care"),
        Keyword(keyword_id=9, category_id=1, keyword_name="Environment"),
        Keyword(keyword_id=10, category_id=7, keyword_name="Food"),
        Keyword(keyword_id=11, category_id=2, keyword_name="Social Justice"),
        Keyword(keyword_id=12, category_id=4, keyword_name="Technology"),
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
            commitment_frequency=CommitmentFrequency.MONTHLY,
            commitment_duration=CommitmentDuration.THREE_TO_SIX,
            status=ProgramStatus.OPEN,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
        Program(
            program_id=2,
            creator_user_id=1,
            category_id=1,
            location_id=2,
            program_name="Bondi Beach Cleanup",
            description=(
                "Help keep Bondi Beach clean by joining our monthly cleanup crew."
            ),
            banner_image_url="https://picsum.photos/seed/prog2/800/400",
            start_datetime=_dt("2026-07-15T07:00:00+00:00"),
            end_datetime=_dt("2026-07-15T10:00:00+00:00"),
            max_volunteers=50,
            commitment_frequency=CommitmentFrequency.MONTHLY,
            commitment_duration=CommitmentDuration.CONTINUOUS,
            status=ProgramStatus.OPEN,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
        Program(
            program_id=3,
            creator_user_id=1,
            category_id=3,
            location_id=3,
            program_name="After-School Reading Club",
            description=(
                "Help local primary students build confidence by reading "
                "together once a week."
            ),
            banner_image_url="https://picsum.photos/seed/prog3/800/400",
            start_datetime=_dt("2026-07-08T15:30:00+00:00"),
            end_datetime=_dt("2026-07-08T17:00:00+00:00"),
            max_volunteers=12,
            commitment_frequency=CommitmentFrequency.WEEKLY,
            commitment_duration=CommitmentDuration.SEVEN_TO_NINE,
            status=ProgramStatus.OPEN,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
        Program(
            program_id=4,
            creator_user_id=1,
            category_id=6,
            location_id=4,
            program_name="Senior Tech Support Drop-In",
            description=(
                "Spend an afternoon helping seniors get comfortable with their "
                "phones and laptops."
            ),
            banner_image_url="https://picsum.photos/seed/prog4/800/400",
            start_datetime=_dt("2026-07-20T13:00:00+00:00"),
            end_datetime=_dt("2026-07-20T16:00:00+00:00"),
            max_volunteers=8,
            commitment_frequency=CommitmentFrequency.WEEKLY,
            commitment_duration=CommitmentDuration.UNDER_2,
            status=ProgramStatus.FULL,
            is_deleted=False,
            deleted_at=None,
            created_at=CREATED_AT,
        ),
    ]
    # Jane's profile interests — "Animal Care" (4) + "Education" (7), matching
    # the chips on the profile mockup.
    user_interests = [
        UserInterest(user_id=1, keyword_id=4),
        UserInterest(user_id=1, keyword_id=7),
    ]
    program_keywords = [
        ProgramKeyword(program_id=1, keyword_id=1),
        ProgramKeyword(program_id=2, keyword_id=2),
    ]
    # The host (user 1) plus the three extra members all join program 1, so the
    # detail screen's Members row has real participants to render (host + 3).
    participations = [
        ProgramParticipation(
            participation_id=pid,
            program_id=1,
            user_id=uid,
            participation_status=ParticipationStatus.APPROVED,
            joined_at=CREATED_AT,
        )
        for pid, uid in enumerate([1, 2, 3, 4], start=1)
    ]
    # Member board questions for program 1, authored across members. Mirrors
    # `MockData.forumPosts` in the iOS app.
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
            author_user_id=3,
            title="Parking nearby?",
            body="Is there parking available near the park entrance?",
            created_at=CREATED_AT,
        ),
        ForumPost(
            post_id=3,
            program_id=1,
            author_user_id=2,
            title="Dress code?",
            body="What should we wear — is there a recommended outfit for the day?",
            created_at=CREATED_AT,
        ),
        ForumPost(
            post_id=4,
            program_id=1,
            author_user_id=4,
            title="Carpool?",
            body="Anyone coming from the north shore keen to share a ride?",
            created_at=CREATED_AT,
        ),
        ForumPost(
            post_id=5,
            program_id=1,
            author_user_id=3,
            title="Lunch provided?",
            body="Will food be provided or should we pack our own?",
            created_at=CREATED_AT,
        ),
        ForumPost(
            post_id=6,
            program_id=1,
            author_user_id=2,
            title="Kids welcome?",
            body="Can I bring my two kids along to help out?",
            created_at=CREATED_AT,
        ),
    ]
    # A threaded conversation on post 1: top-level comments and indented
    # replies via ``parent_comment_id``. Mirrors `MockData.forumComments`.
    forum_comments = [
        ForumComment(
            comment_id=1,
            post_id=1,
            author_user_id=2,
            parent_comment_id=None,
            body="Yes, please bring gloves! Tools will be provided on site.",
            created_at=CREATED_AT,
        ),
        ForumComment(
            comment_id=2,
            post_id=1,
            author_user_id=3,
            parent_comment_id=1,
            body="Great, thanks for confirming.",
            created_at=CREATED_AT,
        ),
        ForumComment(
            comment_id=3,
            post_id=1,
            author_user_id=4,
            parent_comment_id=1,
            body="Are gardening gloves fine, or do we need heavy-duty ones?",
            created_at=CREATED_AT,
        ),
        ForumComment(
            comment_id=4,
            post_id=1,
            author_user_id=1,
            parent_comment_id=3,
            body="Sturdy gardening gloves are perfect.",
            created_at=CREATED_AT,
        ),
        ForumComment(
            comment_id=5,
            post_id=1,
            author_user_id=3,
            parent_comment_id=None,
            body="Also bring a refillable water bottle — it gets warm by midday.",
            created_at=CREATED_AT,
        ),
    ]
    # Likes spread across members so counts and ``liked_by_me`` (user 1) vary.
    # Mirrors the like tallies in `MockData.forumComments`.
    forum_likes = [
        ForumCommentLike(comment_id=2, user_id=1, created_at=CREATED_AT),
        ForumCommentLike(comment_id=2, user_id=3, created_at=CREATED_AT),
        ForumCommentLike(comment_id=3, user_id=4, created_at=CREATED_AT),
        ForumCommentLike(comment_id=4, user_id=2, created_at=CREATED_AT),
        ForumCommentLike(comment_id=4, user_id=3, created_at=CREATED_AT),
        ForumCommentLike(comment_id=4, user_id=4, created_at=CREATED_AT),
        ForumCommentLike(comment_id=5, user_id=1, created_at=CREATED_AT),
        ForumCommentLike(comment_id=5, user_id=2, created_at=CREATED_AT),
        ForumCommentLike(comment_id=5, user_id=3, created_at=CREATED_AT),
        ForumCommentLike(comment_id=5, user_id=4, created_at=CREATED_AT),
    ]

    # Dependency order: parents before children.
    return [
        *locations,
        *categories,
        *keywords,
        user,
        user_profile,
        *member_users,
        *member_profiles,
        *programs,
        *user_interests,
        *program_keywords,
        *participations,
        *forum_posts,
        *forum_comments,
        *forum_likes,
    ]


def seed() -> None:
    # Convenience for fresh local dev DBs; no-ops if Alembic already created them.
    Base.metadata.create_all(engine)

    with session_factory() as session:
        for row in _rows():
            session.merge(row)
        session.commit()
    print("Seeded database with MockData fixtures.")


if __name__ == "__main__":
    seed()
