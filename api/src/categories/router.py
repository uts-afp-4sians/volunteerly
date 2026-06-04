from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.categories.model import Keyword, ProgramCategory
from src.categories.schema import KeywordRead, ProgramCategoryRead
from src.lib.database import get_db

router = APIRouter(tags=["categories"])


@router.get("/categories", response_model=list[ProgramCategoryRead])
async def list_categories(db: AsyncSession = Depends(get_db)) -> list[ProgramCategory]:
    result = await db.execute(
        select(ProgramCategory).order_by(ProgramCategory.category_id)
    )
    return list(result.scalars().all())


@router.get("/keywords", response_model=list[KeywordRead])
async def list_keywords(db: AsyncSession = Depends(get_db)) -> list[Keyword]:
    result = await db.execute(select(Keyword).order_by(Keyword.keyword_id))
    return list(result.scalars().all())
