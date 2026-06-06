from collections.abc import Sequence

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user, get_optional_user
from src.forum.model import ForumComment, ForumCommentLike, ForumPost
from src.forum.schema import (
    ForumCommentCreate,
    ForumCommentRead,
    ForumPostCreate,
    ForumPostRead,
)
from src.lib.database import get_db
from src.programs.model import Program
from src.users.model import User

router = APIRouter(tags=["forum"])


# MARK: - Loaders


def _load_program(program_id: int, db: Session) -> Program:
    program = db.get(Program, program_id)
    if program is None or program.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Program not found"
        )
    return program


def _load_post(program_id: int, post_id: int, db: Session) -> ForumPost:
    post = db.get(ForumPost, post_id)
    if post is None or post.program_id != program_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
        )
    return post


def _load_comment(
    program_id: int, post_id: int, comment_id: int, db: Session
) -> ForumComment:
    _load_post(program_id, post_id, db)
    comment = db.get(ForumComment, comment_id)
    if comment is None or comment.post_id != post_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Comment not found"
        )
    return comment


# MARK: - Read shaping


def _comment_reads(
    comments: Sequence[ForumComment], db: Session, user_id: int | None
) -> list[ForumCommentRead]:
    """Attach ``like_count`` (aggregate) and ``liked_by_me`` (per caller) to a
    batch of comments in two bulk queries — no N+1 per comment."""
    ids = [c.comment_id for c in comments]
    counts: dict[int, int] = {}
    liked: set[int] = set()
    if ids:
        counts = {
            comment_id: count
            for comment_id, count in db.execute(
                select(ForumCommentLike.comment_id, func.count())
                .where(ForumCommentLike.comment_id.in_(ids))
                .group_by(ForumCommentLike.comment_id)
            ).all()
        }
        if user_id is not None:
            liked = set(
                db.execute(
                    select(ForumCommentLike.comment_id).where(
                        ForumCommentLike.comment_id.in_(ids),
                        ForumCommentLike.user_id == user_id,
                    )
                )
                .scalars()
                .all()
            )

    reads: list[ForumCommentRead] = []
    for comment in comments:
        read = ForumCommentRead.model_validate(comment)
        read.like_count = counts.get(comment.comment_id, 0)
        read.liked_by_me = comment.comment_id in liked
        reads.append(read)
    return reads


# MARK: - Posts


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


@router.post(
    "/programs/{program_id}/posts",
    response_model=ForumPostRead,
    status_code=status.HTTP_201_CREATED,
)
def create_program_post(
    program_id: int,
    payload: ForumPostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ForumPost:
    """Open a new question on the program's Member board."""
    _load_program(program_id, db)
    post = ForumPost(
        program_id=program_id,
        author_user_id=current_user.user_id,
        title=payload.title,
        body=payload.body,
    )
    db.add(post)
    db.flush()
    return post


# MARK: - Comments


@router.get(
    "/programs/{program_id}/posts/{post_id}/comments",
    response_model=list[ForumCommentRead],
)
def list_post_comments(
    program_id: int,
    post_id: int,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_user),
) -> list[ForumCommentRead]:
    _load_post(program_id, post_id, db)
    comments = list(
        db.execute(
            select(ForumComment)
            .where(ForumComment.post_id == post_id)
            .order_by(ForumComment.comment_id)
        )
        .scalars()
        .all()
    )
    user_id = current_user.user_id if current_user is not None else None
    return _comment_reads(comments, db, user_id)


@router.post(
    "/programs/{program_id}/posts/{post_id}/comments",
    response_model=ForumCommentRead,
    status_code=status.HTTP_201_CREATED,
)
def create_post_comment(
    program_id: int,
    post_id: int,
    payload: ForumCommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ForumCommentRead:
    """Add a comment, or a reply when ``parent_comment_id`` is supplied."""
    _load_post(program_id, post_id, db)

    if payload.parent_comment_id is not None:
        parent = db.get(ForumComment, payload.parent_comment_id)
        if parent is None or parent.post_id != post_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="parent_comment_id must reference a comment on this post",
            )

    comment = ForumComment(
        post_id=post_id,
        author_user_id=current_user.user_id,
        body=payload.body,
        parent_comment_id=payload.parent_comment_id,
    )
    db.add(comment)
    db.flush()
    return _comment_reads([comment], db, current_user.user_id)[0]


# MARK: - Likes


@router.post(
    "/programs/{program_id}/posts/{post_id}/comments/{comment_id}/like",
    response_model=ForumCommentRead,
)
def like_comment(
    program_id: int,
    post_id: int,
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ForumCommentRead:
    """Like a comment (idempotent — re-liking is a no-op). Returns the comment
    with its refreshed like state."""
    comment = _load_comment(program_id, post_id, comment_id, db)
    existing = db.get(
        ForumCommentLike,
        {"comment_id": comment_id, "user_id": current_user.user_id},
    )
    if existing is None:
        db.add(ForumCommentLike(comment_id=comment_id, user_id=current_user.user_id))
        db.flush()
    return _comment_reads([comment], db, current_user.user_id)[0]


@router.delete(
    "/programs/{program_id}/posts/{post_id}/comments/{comment_id}/like",
    response_model=ForumCommentRead,
)
def unlike_comment(
    program_id: int,
    post_id: int,
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ForumCommentRead:
    """Remove the caller's like (idempotent). Returns the comment with its
    refreshed like state."""
    comment = _load_comment(program_id, post_id, comment_id, db)
    existing = db.get(
        ForumCommentLike,
        {"comment_id": comment_id, "user_id": current_user.user_id},
    )
    if existing is not None:
        db.delete(existing)
        db.flush()
    return _comment_reads([comment], db, current_user.user_id)[0]
