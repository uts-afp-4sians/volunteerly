from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from src.common.enums import ParticipationStatus, ProgramStatus
from src.common.schema import UTCDateTime


class ProgramCreate(BaseModel):
    """Create payload for a new program. The creator is taken from the caller's
    auth token, and ``location_id`` falls back to the first known location when
    omitted (the client's free-text region picker isn't mapped to a location
    row yet)."""

    category_id: int
    program_name: str = Field(min_length=1, max_length=255)
    description: str = Field(min_length=1)
    start_datetime: datetime
    end_datetime: datetime
    max_volunteers: int = Field(ge=1)
    banner_image_url: str | None = None
    location_id: int | None = None


class ProgramRead(BaseModel):
    """Wire shape matching iOS `Program`."""

    model_config = ConfigDict(from_attributes=True, use_enum_values=True)

    program_id: int
    creator_user_id: int
    category_id: int
    location_id: int
    program_name: str
    description: str
    banner_image_url: str | None = None
    start_datetime: UTCDateTime
    end_datetime: UTCDateTime
    max_volunteers: int
    status: ProgramStatus
    is_deleted: bool
    deleted_at: UTCDateTime | None = None
    created_at: UTCDateTime


class ProgramKeywordRead(BaseModel):
    """Wire shape matching iOS `ProgramKeyword`."""

    model_config = ConfigDict(from_attributes=True)

    program_id: int
    keyword_id: int


class ProgramParticipationRead(BaseModel):
    """Wire shape matching iOS `ProgramParticipation`."""

    model_config = ConfigDict(from_attributes=True, use_enum_values=True)

    participation_id: int
    program_id: int
    user_id: int
    participation_status: ParticipationStatus
    joined_at: UTCDateTime


class ProgramBookmarkRead(BaseModel):
    """Wire shape matching iOS `ProgramBookmark`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    program_id: int
    bookmarked_at: UTCDateTime
