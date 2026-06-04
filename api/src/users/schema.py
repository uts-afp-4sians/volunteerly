from pydantic import BaseModel, ConfigDict

from src.common.schema import UTCDateTime


class UserRead(BaseModel):
    """Wire shape matching iOS `User`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    email: str
    is_deleted: bool
    deleted_at: UTCDateTime | None = None
    created_at: UTCDateTime


class UserProfileRead(BaseModel):
    """Wire shape matching iOS `UserProfile`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    first_name: str
    last_name: str
    date_of_birth: UTCDateTime | None = None
    profile_image_url: str | None = None
    occupation: str | None = None
    goal_text: str | None = None
    location_id: int | None = None


class UserInterestRead(BaseModel):
    """Wire shape matching iOS `UserInterest`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    keyword_id: int
