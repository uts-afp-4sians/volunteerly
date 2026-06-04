from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.forum.model import ForumComment, ForumPost
from src.forum.schema import ForumCommentRead, ForumPostRead
from src.lib.database import get_db

router = APIRouter(tags=["forum"])


@router.get("/programs/{program_id}/posts", response_model=list[ForumPostRead])
def list_program_posts(
    program_id: int, db: Session = Depends(get_db)
) -> list[ForumPost]:
    result = db.execute(
        select(ForumPost)
        .where(ForumPost.program_id == program_id)
        .order_by(ForumPost.post_id)
    )
    return list(result.scalars().all())


@router.get(
    "/programs/{program_id}/posts/{post_id}/comments",
    response_model=list[ForumCommentRead],
)
def list_post_comments(
    program_id: int, post_id: int, db: Session = Depends(get_db)
) -> list[ForumComment]:
    result = db.execute(
        select(ForumComment)
        .where(ForumComment.post_id == post_id)
        .order_by(ForumComment.comment_id)
    )
    return list(result.scalars().all())
