from pydantic import BaseModel, ConfigDict

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


class ForumCommentRead(BaseModel):
    """Wire shape matching iOS `ForumComment`."""

    model_config = ConfigDict(from_attributes=True)

    comment_id: int
    post_id: int
    author_user_id: int
    body: str
    created_at: UTCDateTime
