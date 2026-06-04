from pydantic import BaseModel, ConfigDict

from src.common.enums import ParticipationStatus, ProgramStatus
from src.common.schema import UTCDateTime


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
