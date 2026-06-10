from pydantic import BaseModel, ConfigDict, Field

from src.common.schema import UTCDateTime
from src.locations.schema import LocationRead


class UserRead(BaseModel):
    """Wire shape matching iOS `User`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    email: str
    is_deleted: bool
    deleted_at: UTCDateTime | None = None
    created_at: UTCDateTime


class UserInterestRead(BaseModel):
    """Wire shape matching iOS `UserInterest`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    keyword_id: int


class UserInterestDetail(BaseModel):
    """A user's interest joined with its keyword name, for the profile screen."""

    model_config = ConfigDict(from_attributes=True)

    keyword_id: int
    keyword_name: str


class UserProfileRead(BaseModel):
    """Wire shape matching iOS `UserProfile`.

    Interests are embedded here (rather than served from a separate
    ``/me/interests`` resource) so a single profile read hydrates the whole
    screen and caches as one object.
    """

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    first_name: str
    last_name: str
    date_of_birth: UTCDateTime | None = None
    profile_image_url: str | None = None
    occupation: str | None = None
    goal_text: str | None = None
    bio: str | None = None
    instagram: str | None = None
    key_skills: str | None = None
    location_id: int | None = None
    # Embedded like interests: one profile read hydrates the whole screen,
    # including the city shown on My Page.
    location: LocationRead | None = None
    interests: list[UserInterestDetail] = Field(default_factory=list)


class UserProfileUpdate(BaseModel):
    """Partial update for the signed-in user's profile (`PATCH /me/profile`).

    Every field is optional; only fields explicitly present in the request body
    are written, so a client can update a single field without clobbering the
    rest. Use ``model_dump(exclude_unset=True)`` to honour that contract.

    ``interest_keyword_ids`` folds the interest write into the same request: when
    present it replaces the user's whole interest set; when omitted the existing
    interests are left untouched.
    """

    first_name: str | None = Field(default=None, min_length=1, max_length=255)
    last_name: str | None = Field(default=None, max_length=255)
    date_of_birth: UTCDateTime | None = None
    profile_image_url: str | None = Field(default=None, max_length=500)
    occupation: str | None = Field(default=None, max_length=255)
    goal_text: str | None = Field(default=None, max_length=1000)
    bio: str | None = Field(default=None, max_length=1000)
    instagram: str | None = Field(default=None, max_length=255)
    key_skills: str | None = Field(default=None, max_length=500)
    # References an existing row (clients resolve one via POST /locations first).
    location_id: int | None = None
    interest_keyword_ids: list[int] | None = Field(default=None)
