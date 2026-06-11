"""User profile + interest business logic.

Sits between the router (HTTP) and the ORM. Raises domain-meaningful
``UserError`` subclasses; the router maps them to HTTP responses.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from src.categories.model import ProgramCategory
from src.locations.model import Location
from src.locations.schema import LocationRead
from src.users.model import UserInterest, UserProfile
from src.users.schema import UserInterestDetail, UserProfileRead, UserProfileUpdate


class UserError(Exception):
    """Base class for user-domain failures the router translates to HTTP."""


class ProfileNotFound(UserError):
    """The requested user profile does not exist."""


class UnknownCategory(UserError):
    """An interest referenced a category_id that does not exist."""

    def __init__(self, category_id: int) -> None:
        self.category_id = category_id
        super().__init__(f"Unknown category_id: {category_id}")


class UnknownLocation(UserError):
    """The profile referenced a location_id that does not exist."""

    def __init__(self, location_id: int) -> None:
        self.location_id = location_id
        super().__init__(f"Unknown location_id: {location_id}")


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
    leaves it untouched. ``interest_category_ids`` is not a profile column —
    when present it replaces the user's interest set in the same transaction;
    when omitted the interests are left untouched. When no row exists yet (older
    signup flows skipped the auto-create), this upserts: the profile is
    created from the patch payload, with empty strings filling the non-null
    name columns if the caller didn't provide them. Runs in the caller's
    request-scoped transaction.
    """
    data = payload.model_dump(exclude_unset=True)
    interest_category_ids = data.pop("interest_category_ids", None)
    location_id = data.get("location_id")
    if location_id is not None and db.get(Location, location_id) is None:
        raise UnknownLocation(location_id)
    profile = db.get(UserProfile, user_id)
    if profile is None:
        profile = UserProfile(
            user_id=user_id,
            first_name=data.pop("first_name", ""),
            last_name=data.pop("last_name", ""),
            **data,
        )
        db.add(profile)
    else:
        for field, value in data.items():
            setattr(profile, field, value)
    if interest_category_ids is not None:
        replace_interests(db, user_id, interest_category_ids)
    db.flush()
    return profile


def list_interests(db: Session, user_id: int) -> list[ProgramCategory]:
    """Return the categories the user has marked as interests, ordered by id."""
    result = db.execute(
        select(ProgramCategory)
        .join(
            UserInterest, UserInterest.category_id == ProgramCategory.category_id
        )
        .where(UserInterest.user_id == user_id)
        .order_by(ProgramCategory.category_id)
    )
    return list(result.scalars().all())


def replace_interests(
    db: Session, user_id: int, category_ids: list[int]
) -> list[ProgramCategory]:
    """Replace the user's interest set with ``category_ids`` (deduplicated).

    Validates every category exists before mutating, so a bad id rejects the
    whole request rather than leaving a partial set. One delete + N inserts in
    the caller's transaction.
    """
    unique_ids = list(dict.fromkeys(category_ids))  # preserve order, drop dupes
    if unique_ids:
        existing = set(
            db.execute(
                select(ProgramCategory.category_id).where(
                    ProgramCategory.category_id.in_(unique_ids)
                )
            ).scalars()
        )
        for category_id in unique_ids:
            if category_id not in existing:
                raise UnknownCategory(category_id)

    db.execute(UserInterest.__table__.delete().where(UserInterest.user_id == user_id))
    for category_id in unique_ids:
        db.add(UserInterest(user_id=user_id, category_id=category_id))
    db.flush()
    return list_interests(db, user_id)


def read_profile_with_interests(db: Session, profile: UserProfile) -> UserProfileRead:
    """Serialise a profile with its interest set embedded.

    The single shape the profile endpoints return, so one read hydrates the
    whole screen and the client caches it as one object.
    """
    response = UserProfileRead.model_validate(profile)
    if profile.location_id is not None:
        if location := db.get(Location, profile.location_id):
            response.location = LocationRead.model_validate(location)
    response.interests = [
        UserInterestDetail.model_validate(category)
        for category in list_interests(db, profile.user_id)
    ]
    return response
