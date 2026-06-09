from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.categories.model import Keyword, ProgramCategory
from src.categories.schema import KeywordRead, ProgramCategoryRead
from src.lib.database import get_db

router = APIRouter(tags=["categories"])


@router.get("/categories", response_model=list[ProgramCategoryRead])
def list_categories(db: Session = Depends(get_db)) -> list[ProgramCategory]:
    result = db.execute(select(ProgramCategory).order_by(ProgramCategory.category_id))
    return list(result.scalars().all())


@router.get("/keywords", response_model=list[KeywordRead])
def list_keywords(db: Session = Depends(get_db)) -> list[Keyword]:
    result = db.execute(select(Keyword).order_by(Keyword.keyword_id))
    return list(result.scalars().all())


@router.get("/interests", response_model=list[KeywordRead])
def list_interests(db: Session = Depends(get_db)) -> list[Keyword]:
    """The profile-interest catalog — the chips on the signup interests step."""
    result = db.execute(
        select(Keyword)
        .where(Keyword.is_interest.is_(True))
        .order_by(Keyword.keyword_id)
    )
    return list(result.scalars().all())
