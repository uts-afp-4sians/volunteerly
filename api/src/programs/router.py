from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user
from src.categories.model import ProgramCategory
from src.common.enums import (
    CommitmentDuration,
    CommitmentFrequency,
    ProgramStatus,
    TeamSize,
)
from src.lib.database import get_db
from src.locations.model import Location
from src.programs.model import Program, ProgramKeyword
from src.programs.schema import ProgramCreate, ProgramKeywordRead, ProgramRead
from src.users.model import User

router = APIRouter(tags=["programs"])

# Team-size buckets → inclusive ``max_volunteers`` bounds (upper ``None`` = open).
_TEAM_SIZE_BOUNDS: dict[TeamSize, tuple[int, int | None]] = {
    TeamSize.SMALL: (2, 3),
    TeamSize.MEDIUM: (4, 6),
    TeamSize.LARGE: (7, 10),
    TeamSize.OPEN: (11, None),
}


@router.get("/programs", response_model=list[ProgramRead])
def list_programs(
    db: Session = Depends(get_db),
    q: str | None = Query(default=None, description="Search in name/description"),
    category_id: int | None = None,
    team_size: list[TeamSize] | None = Query(default=None),
    commitment_frequency: list[CommitmentFrequency] | None = Query(default=None),
    commitment_duration: list[CommitmentDuration] | None = Query(default=None),
) -> list[Program]:
    """List non-deleted programs, optionally narrowed by query-string filters.
    Repeated params (``team_size``, ``commitment_frequency``,
    ``commitment_duration``) are OR-ed within a group and AND-ed across groups."""
    stmt = select(Program).where(Program.is_deleted.is_(False))

    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            or_(Program.program_name.ilike(like), Program.description.ilike(like))
        )
    if category_id is not None:
        stmt = stmt.where(Program.category_id == category_id)
    if team_size:
        bounds = [_TEAM_SIZE_BOUNDS[t] for t in team_size]
        stmt = stmt.where(
            or_(
                *(
                    Program.max_volunteers >= lo
                    if hi is None
                    else Program.max_volunteers.between(lo, hi)
                    for lo, hi in bounds
                )
            )
        )
    if commitment_frequency:
        stmt = stmt.where(Program.commitment_frequency.in_(commitment_frequency))
    if commitment_duration:
        stmt = stmt.where(Program.commitment_duration.in_(commitment_duration))

    result = db.execute(stmt.order_by(Program.program_id))
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
        commitment_frequency=payload.commitment_frequency,
        commitment_duration=payload.commitment_duration,
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
