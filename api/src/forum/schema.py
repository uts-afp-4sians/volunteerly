from pydantic import BaseModel, ConfigDict, Field

from src.common.schema import UTCDateTime


class ForumPostRead(BaseModel):
    """Wire shape matching iOS `ForumPost`."""

    model_config = ConfigDict(from_attributes=True)

    post_id: int
    program_id: int
    author_user_id: int
    title: str
    body: str
    created_at: UTCDateTime


class ForumPostCreate(BaseModel):
    """Payload to open a new question on a program's Member board."""

    title: str = Field(min_length=1, max_length=255)
    body: str = Field(min_length=1)


class ForumCommentRead(BaseModel):
    """Wire shape matching iOS `ForumComment`.

    ``parent_comment_id`` carries the reply threading; ``like_count`` and
    ``liked_by_me`` are computed per request (not stored on the row), so they
    default here and the router fills them in.
    """

    model_config = ConfigDict(from_attributes=True)

    comment_id: int
    post_id: int
    author_user_id: int
    body: str
    created_at: UTCDateTime
    parent_comment_id: int | None = None
    like_count: int = 0
    liked_by_me: bool = False


class ForumCommentCreate(BaseModel):
    """Payload to add a comment, or a reply when ``parent_comment_id`` is set."""

    body: str = Field(min_length=1)
    parent_comment_id: int | None = None
