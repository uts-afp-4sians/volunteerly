from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user
from src.categories.model import ProgramCategory
from src.common.enums import ProgramStatus
from src.lib.database import get_db
from src.locations.model import Location
from src.programs.model import Program, ProgramKeyword
from src.programs.schema import ProgramCreate, ProgramKeywordRead, ProgramRead
from src.users.model import User

router = APIRouter(tags=["programs"])


@router.get("/programs", response_model=list[ProgramRead])
def list_programs(db: Session = Depends(get_db)) -> list[Program]:
    result = db.execute(
        select(Program)
        .where(Program.is_deleted.is_(False))
        .order_by(Program.program_id)
    )
    return list(result.scalars().all())


@router.post(
    "/programs", response_model=ProgramRead, status_code=status.HTTP_201_CREATED
)
def create_program(
    payload: ProgramCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Program:
    if payload.end_datetime <= payload.start_datetime:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_datetime must be after start_datetime",
        )
    if db.get(ProgramCategory, payload.category_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Category not found"
        )

    location_id = payload.location_id
    if location_id is None:
        location_id = db.execute(
            select(Location.location_id).order_by(Location.location_id)
        ).scalars().first()
        if location_id is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No location available; provide location_id",
            )
    elif db.get(Location, location_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Location not found"
        )

    program = Program(
        creator_user_id=current_user.user_id,
        category_id=payload.category_id,
        location_id=location_id,
        program_name=payload.program_name,
        description=payload.description,
        banner_image_url=payload.banner_image_url,
        start_datetime=payload.start_datetime,
        end_datetime=payload.end_datetime,
        max_volunteers=payload.max_volunteers,
        status=ProgramStatus.OPEN,
    )
    db.add(program)
    db.flush()
    return program


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
