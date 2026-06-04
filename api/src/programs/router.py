from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.lib.database import get_db
from src.programs.model import Program, ProgramKeyword
from src.programs.schema import ProgramKeywordRead, ProgramRead

router = APIRouter(tags=["programs"])


@router.get("/programs", response_model=list[ProgramRead])
def list_programs(db: Session = Depends(get_db)) -> list[Program]:
    result = db.execute(
        select(Program)
        .where(Program.is_deleted.is_(False))
        .order_by(Program.program_id)
    )
    return list(result.scalars().all())


@router.get("/programs/{program_id}", response_model=ProgramRead)
def get_program(program_id: int, db: Session = Depends(get_db)) -> Program:
    program = db.get(Program, program_id)
    if program is None or program.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Program not found"
        )
    return program


@router.get("/programs/{program_id}/keywords", response_model=list[ProgramKeywordRead])
def list_program_keywords(
    program_id: int, db: Session = Depends(get_db)
) -> list[ProgramKeyword]:
    result = db.execute(
        select(ProgramKeyword)
        .where(ProgramKeyword.program_id == program_id)
        .order_by(ProgramKeyword.keyword_id)
    )
    return list(result.scalars().all())
