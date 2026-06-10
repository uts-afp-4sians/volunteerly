from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from src.common.enums import (
    CommitmentDuration,
    CommitmentFrequency,
    ParticipationStatus,
    ProgramStatus,
)
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
    commitment_frequency: CommitmentFrequency | None = None
    commitment_duration: CommitmentDuration | None = None
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
    commitment_frequency: CommitmentFrequency | None = None
    commitment_duration: CommitmentDuration | None = None
    status: ProgramStatus
    is_deleted: bool
    deleted_at: UTCDateTime | None = None
    created_at: UTCDateTime
    # Capacity state belongs to the program resource itself, so the detail fetch
    # carries the Join counter without a second round-trip. Populated by both
    # ``GET /programs/{id}`` and ``GET /programs`` (the list uses one grouped
    # count, not an N+1); only the mock/ORM passthrough leaves it ``None``.
    participant_count: int | None = None
    is_full: bool | None = None
    # Straight-line distance (km) from the caller's coordinates to the program's
    # location, set by ``GET /programs`` only when ``lat``/``lng`` are supplied
    # and the location has coordinates; ``None`` otherwise.
    distance_km: float | None = None


class SimilarProgramRead(BaseModel):
    """A single "nearby" suggestion for the program detail screen, picked
    server-side with a bounded ``LIMIT 1`` query. ``distance_km`` is the
    straight-line distance from the source program when both have coordinates,
    else ``None`` (the match was made by city/region/category)."""

    program: ProgramRead
    distance_km: float | None = None


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


class ProgramParticipantRead(BaseModel):
    """A program participant with the profile fields the Members row renders
    (name + avatar). A subset of iOS `UserProfile`, so it decodes into the same
    model client-side."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    first_name: str
    last_name: str
    profile_image_url: str | None = None


class ProgramParticipationSummary(BaseModel):
    """Capacity snapshot for a program from the caller's perspective, used by the
    iOS detail screen to render the Join counter and gate the Join button."""

    program_id: int
    participant_count: int
    max_volunteers: int
    is_full: bool
    joined: bool


class ProgramBookmarkRead(BaseModel):
    """Wire shape matching iOS `ProgramBookmark`."""

    model_config = ConfigDict(from_attributes=True)

    user_id: int
    program_id: int
    bookmarked_at: UTCDateTime
