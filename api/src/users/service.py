"""User profile + interest business logic.

Sits between the router (HTTP) and the ORM. Raises domain-meaningful
``UserError`` subclasses; the router maps them to HTTP responses.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from src.categories.model import Keyword
from src.users.model import UserInterest, UserProfile
from src.users.schema import UserProfileUpdate


class UserError(Exception):
    """Base class for user-domain failures the router translates to HTTP."""


class ProfileNotFound(UserError):
    """The requested user profile does not exist."""


class UnknownKeyword(UserError):
    """An interest referenced a keyword_id that does not exist."""

    def __init__(self, keyword_id: int) -> None:
        self.keyword_id = keyword_id
        super().__init__(f"Unknown keyword_id: {keyword_id}")


def get_profile(db: Session, user_id: int) -> UserProfile:
    """Return the user's profile or raise ``ProfileNotFound``."""
    profile = db.get(UserProfile, user_id)
    if profile is None:
        raise ProfileNotFound
    return profile


def update_profile(
    db: Session, user_id: int, payload: UserProfileUpdate
) -> UserProfile:
    """Apply a partial update to the user's profile.

    Only fields explicitly set on ``payload`` are written, so omitting a field
    leaves it untouched. Runs in the caller's request-scoped transaction.
    """
    profile = get_profile(db, user_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)
    db.flush()
    return profile


def list_interests(db: Session, user_id: int) -> list[Keyword]:
    """Return the keywords the user has marked as interests, ordered by id."""
    result = db.execute(
        select(Keyword)
        .join(UserInterest, UserInterest.keyword_id == Keyword.keyword_id)
        .where(UserInterest.user_id == user_id)
        .order_by(Keyword.keyword_id)
    )
    return list(result.scalars().all())


def replace_interests(
    db: Session, user_id: int, keyword_ids: list[int]
) -> list[Keyword]:
    """Replace the user's interest set with ``keyword_ids`` (deduplicated).

    Validates every keyword exists before mutating, so a bad id rejects the
    whole request rather than leaving a partial set. One delete + N inserts in
    the caller's transaction.
    """
    unique_ids = list(dict.fromkeys(keyword_ids))  # preserve order, drop dupes
    if unique_ids:
        existing = set(
            db.execute(
                select(Keyword.keyword_id).where(Keyword.keyword_id.in_(unique_ids))
            ).scalars()
        )
        for keyword_id in unique_ids:
            if keyword_id not in existing:
                raise UnknownKeyword(keyword_id)

    db.execute(UserInterest.__table__.delete().where(UserInterest.user_id == user_id))
    for keyword_id in unique_ids:
        db.add(UserInterest(user_id=user_id, keyword_id=keyword_id))
    db.flush()
    return list_interests(db, user_id)
