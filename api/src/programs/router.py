import math

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user
from src.categories.model import ProgramCategory
from src.common.enums import (
    CommitmentDuration,
    CommitmentFrequency,
    ParticipationStatus,
    ProgramStatus,
    TeamSize,
)
from src.lib.database import get_db
from src.locations.model import Location
from src.programs.model import Program, ProgramKeyword, ProgramParticipation
from src.programs.schema import (
    ProgramCreate,
    ProgramKeywordRead,
    ProgramParticipationSummary,
    ProgramRead,
    SimilarProgramRead,
)
from src.users.model import User

router = APIRouter(tags=["programs"])

# Team-size buckets → inclusive ``max_volunteers`` bounds (upper ``None`` = open).
_TEAM_SIZE_BOUNDS: dict[TeamSize, tuple[int, int | None]] = {
    TeamSize.SMALL: (2, 3),
    TeamSize.MEDIUM: (4, 6),
    TeamSize.LARGE: (7, 10),
    TeamSize.OPEN: (11, None),
}

# Participation states that occupy a volunteer slot (count toward capacity).
_ACTIVE_PARTICIPATION = (
    ParticipationStatus.PENDING,
    ParticipationStatus.APPROVED,
)


def _haversine_coords(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance between two lat/lon pairs in km, rounded to 0.1."""
    lat1, lon1, lat2, lon2 = map(math.radians, (lat1, lon1, lat2, lon2))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    return round(2 * 6371.0 * math.asin(math.sqrt(h)), 1)


def _haversine_km(a: Location, b: Location) -> float | None:
    """Great-circle distance between two locations in km, or ``None`` when
    either is missing coordinates."""
    if None in (a.latitude, a.longitude, b.latitude, b.longitude):
        return None
    return _haversine_coords(a.latitude, a.longitude, b.latitude, b.longitude)


def _load_program(program_id: int, db: Session) -> Program:
    program = db.get(Program, program_id)
    if program is None or program.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Program not found"
        )
    return program


def _participant_count(program_id: int, db: Session) -> int:
    """Number of volunteers currently occupying a slot in the program."""
    return db.execute(
        select(func.count())
        .select_from(ProgramParticipation)
        .where(
            ProgramParticipation.program_id == program_id,
            ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
        )
    ).scalar_one()


def _participant_counts(program_ids: list[int], db: Session) -> dict[int, int]:
    """Active participant counts for many programs in a single grouped query
    (avoids an N+1 when enriching a list). Programs with no active participations
    are absent from the map — callers default those to 0."""
    if not program_ids:
        return {}
    rows = db.execute(
        select(ProgramParticipation.program_id, func.count())
        .where(
            ProgramParticipation.program_id.in_(program_ids),
            ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
        )
        .group_by(ProgramParticipation.program_id)
    ).all()
    return {program_id: count for program_id, count in rows}


def _active_participation(
    program_id: int, user_id: int, db: Session
) -> ProgramParticipation | None:
    """The caller's current (non-withdrawn) participation, if any."""
    return (
        db.execute(
            select(ProgramParticipation).where(
                ProgramParticipation.program_id == program_id,
                ProgramParticipation.user_id == user_id,
                ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
            )
        )
        .scalars()
        .first()
    )


@router.get("/programs", response_model=list[ProgramRead])
def list_programs(
    db: Session = Depends(get_db),
    q: str | None = Query(default=None, description="Search in name/description"),
    category_id: int | None = None,
    team_size: list[TeamSize] | None = Query(default=None),
    commitment_frequency: list[CommitmentFrequency] | None = Query(default=None),
    commitment_duration: list[CommitmentDuration] | None = Query(default=None),
    lat: float | None = Query(
        default=None, ge=-90, le=90, description="Caller latitude for distance"
    ),
    lng: float | None = Query(
        default=None, ge=-180, le=180, description="Caller longitude for distance"
    ),
) -> list[ProgramRead]:
    """List non-deleted programs, optionally narrowed by query-string filters.
    Repeated params (``team_size``, ``commitment_frequency``,
    ``commitment_duration``) are OR-ed within a group and AND-ed across groups.
    When ``lat``/``lng`` are supplied, each program carries ``distance_km`` —
    the straight-line distance from the caller to its location."""
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

    programs = list(db.execute(stmt.order_by(Program.program_id)).scalars().all())

    # The card shows how many volunteers have joined (the host included, as they
    # hold an ordinary participation row), so carry the count on every list row.
    # One grouped query keeps this O(1) rather than a count per program.
    counts = _participant_counts([p.program_id for p in programs], db)

    # Distance needs the caller's coordinates; without them ``distance_km`` stays
    # ``None``. When present, one bulk location lookup avoids an N+1 per program.
    locations: dict[int, Location] = {}
    if lat is not None and lng is not None:
        location_ids = {p.location_id for p in programs}
        locations = {
            loc.location_id: loc
            for loc in db.execute(
                select(Location).where(Location.location_id.in_(location_ids))
            )
            .scalars()
            .all()
        }

    reads: list[ProgramRead] = []
    for program in programs:
        read = ProgramRead.model_validate(program)
        count = counts.get(program.program_id, 0)
        read.participant_count = count
        read.is_full = count >= program.max_volunteers
        loc = locations.get(program.location_id)
        if loc is not None and loc.latitude is not None and loc.longitude is not None:
            read.distance_km = _haversine_coords(lat, lng, loc.latitude, loc.longitude)
        reads.append(read)
    return reads


@router.post(
    "/programs", response_model=ProgramRead, status_code=status.HTTP_201_CREATED
)
def create_program(
    payload: ProgramCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProgramRead:
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
        location_id = (
            db.execute(select(Location.location_id).order_by(Location.location_id))
            .scalars()
            .first()
        )
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
    # Auto-enroll the creator so participant_count starts at 1 (host occupies a slot).
    db.add(
        ProgramParticipation(
            program_id=program.program_id,
            user_id=current_user.user_id,
            participation_status=ParticipationStatus.APPROVED,
        )
    )
    read = ProgramRead.model_validate(program)
    read.participant_count = 1
    read.is_full = program.max_volunteers <= 1
    return read


@router.get("/programs/{program_id}", response_model=ProgramRead)
def get_program(program_id: int, db: Session = Depends(get_db)) -> ProgramRead:
    program = _load_program(program_id, db)
    count = _participant_count(program_id, db)
    read = ProgramRead.model_validate(program)
    read.participant_count = count
    read.is_full = count >= program.max_volunteers
    return read


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


@router.get("/programs/{program_id}/similar", response_model=SimilarProgramRead)
def get_similar_program(
    program_id: int, db: Session = Depends(get_db)
) -> SimilarProgramRead:
    """One "nearby" program to suggest on the detail screen.

    Picked server-side so the client never pulls whole tables: each strategy is a
    bounded ``LIMIT 1`` query. Prefers the geographically nearest program (when
    coordinates exist), then the same city, region, category, and finally any
    other program. ``distance_km`` is set only for the coordinate-based match.
    """
    target = _load_program(program_id, db)
    target_location = db.get(Location, target.location_id)

    base = select(Program).where(
        Program.is_deleted.is_(False),
        Program.program_id != program_id,
    )

    # 1. Nearest by coordinates. A planar (lat/lon squared) term is enough to
    #    *order* candidates at city scale; the precise haversine is computed once
    #    for the single winning row.
    if (
        target_location is not None
        and target_location.latitude is not None
        and target_location.longitude is not None
    ):
        dlat = Location.latitude - target_location.latitude
        dlon = Location.longitude - target_location.longitude
        nearest = (
            db.execute(
                base.join(Location, Program.location_id == Location.location_id)
                .where(Location.latitude.is_not(None), Location.longitude.is_not(None))
                .order_by(dlat * dlat + dlon * dlon)
                .limit(1)
            )
            .scalars()
            .first()
        )
        if nearest is not None:
            return SimilarProgramRead(
                program=ProgramRead.model_validate(nearest),
                distance_km=_haversine_km(
                    target_location, db.get(Location, nearest.location_id)
                ),
            )

    # 2. Same city → same region (each a bounded LIMIT 1).
    if target_location is not None:
        region_clauses = [Location.city == target_location.city]
        if target_location.state_region is not None:
            region_clauses.append(Location.state_region == target_location.state_region)
        for clause in region_clauses:
            match = (
                db.execute(
                    base.join(Location, Program.location_id == Location.location_id)
                    .where(clause)
                    .order_by(Program.program_id)
                    .limit(1)
                )
                .scalars()
                .first()
            )
            if match is not None:
                return SimilarProgramRead(program=ProgramRead.model_validate(match))

    # 3. Same category, then any other program.
    fallback = (
        db.execute(
            base.where(Program.category_id == target.category_id)
            .order_by(Program.program_id)
            .limit(1)
        )
        .scalars()
        .first()
    )
    if fallback is None:
        fallback = (
            db.execute(base.order_by(Program.program_id).limit(1)).scalars().first()
        )

    if fallback is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="No similar program found"
        )
    return SimilarProgramRead(program=ProgramRead.model_validate(fallback))


def _summary(
    program: Program, db: Session, user_id: int
) -> ProgramParticipationSummary:
    count = _participant_count(program.program_id, db)
    return ProgramParticipationSummary(
        program_id=program.program_id,
        participant_count=count,
        max_volunteers=program.max_volunteers,
        is_full=count >= program.max_volunteers,
        joined=_active_participation(program.program_id, user_id, db) is not None,
    )


@router.get(
    "/programs/{program_id}/participations",
    response_model=ProgramParticipationSummary,
)
def get_participation_summary(
    program_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProgramParticipationSummary:
    """Capacity snapshot for the Join counter, including whether the caller has
    already joined."""
    program = _load_program(program_id, db)
    return _summary(program, db, current_user.user_id)


@router.post(
    "/programs/{program_id}/participations",
    response_model=ProgramParticipationSummary,
    status_code=status.HTTP_201_CREATED,
)
def join_program(
    program_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProgramParticipationSummary:
    """Join the program as the authenticated user, returning the refreshed
    capacity snapshot. Rejects joins when the program isn't open, is at
    capacity, or the caller has already joined."""
    program = _load_program(program_id, db)

    if program.status in (ProgramStatus.CLOSED, ProgramStatus.CANCELLED):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Program is not open for joining",
        )
    if _active_participation(program_id, current_user.user_id, db) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already joined this program",
        )
    if _participant_count(program_id, db) >= program.max_volunteers:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Program is full"
        )

    db.add(
        ProgramParticipation(
            program_id=program_id,
            user_id=current_user.user_id,
            participation_status=ParticipationStatus.APPROVED,
        )
    )
    db.flush()

    summary = _summary(program, db, current_user.user_id)
    # Flip the program to FULL once the last slot is taken.
    if summary.is_full:
        program.status = ProgramStatus.FULL
    return summary


@router.delete(
    "/programs/{program_id}/participations",
    status_code=status.HTTP_204_NO_CONTENT,
)
def leave_program(
    program_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    """Withdraw the authenticated user's participation, freeing their slot."""
    program = _load_program(program_id, db)
    participation = _active_participation(program_id, current_user.user_id, db)
    if participation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not joined this program",
        )

    participation.participation_status = ParticipationStatus.WITHDRAWN
    # A withdrawal frees a slot, so a FULL program reopens.
    if program.status == ProgramStatus.FULL:
        program.status = ProgramStatus.OPEN

    return Response(status_code=status.HTTP_204_NO_CONTENT)
