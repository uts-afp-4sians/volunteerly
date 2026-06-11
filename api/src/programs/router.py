import math
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import and_, delete, func, or_, select
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
from src.programs.model import (
    Program,
    ProgramImage,
    ProgramKeyword,
    ProgramParticipation,
)
from src.programs.schema import (
    ProgramCreate,
    ProgramKeywordRead,
    ProgramParticipantRead,
    ProgramParticipationSummary,
    ProgramRead,
    ProgramUpdate,
    SimilarProgramRead,
)
from src.users.model import User, UserProfile

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


def _creator_has_row(program: Program, db: Session) -> bool:
    """Whether the program's creator holds any participation row (active or
    withdrawn). Programs created before creator auto-enrolment (and seeded
    fixtures) have none, so the host is counted explicitly; once a row exists we
    respect its status — a withdrawn host has intentionally left their slot."""
    return (
        db.execute(
            select(ProgramParticipation.participation_id).where(
                ProgramParticipation.program_id == program.program_id,
                ProgramParticipation.user_id == program.creator_user_id,
            )
        ).first()
        is not None
    )


def _participant_count(program: Program, db: Session) -> int:
    """Number of volunteers occupying a slot, with the host always counted once.

    The host occupies a slot whether or not they hold a participation row: new
    programs auto-enroll the creator (so they have a row), but older programs
    don't. Counting the host explicitly when no creator row exists keeps the
    tally correct for both, without double-counting once a row is present."""
    active = db.execute(
        select(func.count())
        .select_from(ProgramParticipation)
        .where(
            ProgramParticipation.program_id == program.program_id,
            ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
        )
    ).scalar_one()
    return active + (0 if _creator_has_row(program, db) else 1)


def _participant_counts(programs: list[Program], db: Session) -> dict[int, int]:
    """Host-inclusive active participant counts for many programs in two grouped
    queries (avoids an N+1 when enriching a list). Every program is present in
    the map — the host contributes the implicit +1 when it holds no row."""
    if not programs:
        return {}
    ids = [p.program_id for p in programs]
    rows = db.execute(
        select(ProgramParticipation.program_id, func.count())
        .where(
            ProgramParticipation.program_id.in_(ids),
            ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
        )
        .group_by(ProgramParticipation.program_id)
    ).all()
    active = {program_id: count for program_id, count in rows}
    # Programs whose creator already holds a row (active or withdrawn) don't get
    # the implicit host +1 — mirrors ``_creator_has_row`` for the bulk path.
    creators_present = set(
        db.execute(
            select(ProgramParticipation.program_id)
            .join(Program, Program.program_id == ProgramParticipation.program_id)
            .where(
                ProgramParticipation.program_id.in_(ids),
                ProgramParticipation.user_id == Program.creator_user_id,
            )
        )
        .scalars()
        .all()
    )
    return {
        p.program_id: active.get(p.program_id, 0)
        + (0 if p.program_id in creators_present else 1)
        for p in programs
    }


def _program_images(program_ids: list[int], db: Session) -> dict[int, list[str]]:
    """Ordered banner-gallery URLs for many programs in one grouped query
    (avoids an N+1 when enriching a list). Programs without images are absent
    from the map; callers fall back to the legacy ``banner_image_url``."""
    if not program_ids:
        return {}
    rows = db.execute(
        select(ProgramImage.program_id, ProgramImage.image_url)
        .where(ProgramImage.program_id.in_(program_ids))
        .order_by(
            ProgramImage.program_id,
            ProgramImage.sort_order,
            ProgramImage.image_id,
        )
    ).all()
    out: dict[int, list[str]] = {}
    for program_id, url in rows:
        out.setdefault(program_id, []).append(url)
    return out


def _hydrate_images(read: ProgramRead, urls: list[str]) -> None:
    """Populate ``banner_image_urls`` (and keep ``banner_image_url`` in sync with
    the first image). Falls back to the legacy single banner when the program
    has no gallery rows, so old data still renders one image."""
    if urls:
        read.banner_image_urls = urls
        read.banner_image_url = urls[0]
    elif read.banner_image_url:
        read.banner_image_urls = [read.banner_image_url]


def _read_with_images(program: Program, db: Session) -> ProgramRead:
    """``ProgramRead`` for a single program with its banner gallery hydrated."""
    read = ProgramRead.model_validate(program)
    urls = _program_images([program.program_id], db).get(program.program_id, [])
    _hydrate_images(read, urls)
    return read


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
    category_id: list[int] | None = Query(default=None),
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
    Repeated params (``category_id``, ``team_size``, ``commitment_frequency``,
    ``commitment_duration``) are OR-ed within a group and AND-ed across groups.
    When ``lat``/``lng`` are supplied, each program carries ``distance_km`` —
    the straight-line distance from the caller to its location."""
    stmt = select(Program).where(Program.is_deleted.is_(False))

    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            or_(Program.program_name.ilike(like), Program.description.ilike(like))
        )
    if category_id:
        stmt = stmt.where(Program.category_id.in_(category_id))
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
    counts = _participant_counts(programs, db)

    # Ordered banner galleries for every program in one grouped query, so the
    # card/detail carousel never triggers an N+1.
    images = _program_images([p.program_id for p in programs], db)

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
        _hydrate_images(read, images.get(program.program_id, []))
        loc = locations.get(program.location_id)
        if loc is not None and loc.latitude is not None and loc.longitude is not None:
            read.distance_km = _haversine_coords(lat, lng, loc.latitude, loc.longitude)
        reads.append(read)
    return reads


@router.get("/me/programs", response_model=list[ProgramRead])
def list_my_programs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ProgramRead]:
    """Programs the caller is part of, backing My Page's "My programs" list.

    A program qualifies when the caller holds an active (pending/approved)
    participation, or created it before creator auto-enrolment existed and so
    holds no participation row at all — a withdrawn row means they left on
    purpose (mirrors ``_creator_has_row``). Soft-deleted programs are excluded.
    Rows carry the same capacity/banner enrichment as ``GET /programs``."""
    my_active = select(ProgramParticipation.program_id).where(
        ProgramParticipation.user_id == current_user.user_id,
        ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
    )
    my_any = select(ProgramParticipation.program_id).where(
        ProgramParticipation.user_id == current_user.user_id
    )
    programs = list(
        db.execute(
            select(Program)
            .where(
                Program.is_deleted.is_(False),
                or_(
                    Program.program_id.in_(my_active),
                    and_(
                        Program.creator_user_id == current_user.user_id,
                        Program.program_id.not_in(my_any),
                    ),
                ),
            )
            .order_by(Program.start_datetime, Program.program_id)
        )
        .scalars()
        .all()
    )

    counts = _participant_counts(programs, db)
    images = _program_images([p.program_id for p in programs], db)

    reads: list[ProgramRead] = []
    for program in programs:
        read = ProgramRead.model_validate(program)
        count = counts.get(program.program_id, 0)
        read.participant_count = count
        read.is_full = count >= program.max_volunteers
        _hydrate_images(read, images.get(program.program_id, []))
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

    # Resolve the banner gallery: an explicit list wins, else the legacy single
    # banner seeds a one-image gallery. The first image is the legacy banner.
    gallery = payload.banner_image_urls
    if gallery is None:
        gallery = [payload.banner_image_url] if payload.banner_image_url else []

    program = Program(
        creator_user_id=current_user.user_id,
        category_id=payload.category_id,
        location_id=location_id,
        program_name=payload.program_name,
        description=payload.description,
        banner_image_url=gallery[0] if gallery else None,
        start_datetime=payload.start_datetime,
        end_datetime=payload.end_datetime,
        max_volunteers=payload.max_volunteers,
        commitment_frequency=payload.commitment_frequency,
        commitment_duration=payload.commitment_duration,
        status=ProgramStatus.OPEN,
    )
    db.add(program)
    db.flush()
    for sort_order, url in enumerate(gallery):
        db.add(
            ProgramImage(
                program_id=program.program_id,
                image_url=url,
                sort_order=sort_order,
            )
        )
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
    _hydrate_images(read, gallery)
    return read


@router.get("/programs/{program_id}", response_model=ProgramRead)
def get_program(program_id: int, db: Session = Depends(get_db)) -> ProgramRead:
    program = _load_program(program_id, db)
    count = _participant_count(program, db)
    read = ProgramRead.model_validate(program)
    read.participant_count = count
    read.is_full = count >= program.max_volunteers
    _hydrate_images(read, _program_images([program_id], db).get(program_id, []))
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


@router.get(
    "/programs/{program_id}/participants",
    response_model=list[ProgramParticipantRead],
)
def list_participants(
    program_id: int, db: Session = Depends(get_db)
) -> list[UserProfile]:
    """Active participants of a program with the profile fields the Members row
    renders (name + avatar), oldest join first. Public, like the profile and
    keyword sub-resources. The host appears here only when they hold a row; the
    detail screen draws the host separately from ``creator_user_id``."""
    _load_program(program_id, db)
    return list(
        db.execute(
            select(UserProfile)
            .join(
                ProgramParticipation,
                ProgramParticipation.user_id == UserProfile.user_id,
            )
            .where(
                ProgramParticipation.program_id == program_id,
                ProgramParticipation.participation_status.in_(_ACTIVE_PARTICIPATION),
            )
            .order_by(ProgramParticipation.joined_at)
        )
        .scalars()
        .all()
    )


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
                program=_read_with_images(nearest, db),
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
                return SimilarProgramRead(program=_read_with_images(match, db))

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
    return SimilarProgramRead(program=_read_with_images(fallback, db))


def _summary(
    program: Program, db: Session, user_id: int
) -> ProgramParticipationSummary:
    count = _participant_count(program, db)
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
    if _participant_count(program, db) >= program.max_volunteers:
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


# Host-only management — only the program's creator can edit or delete it.


def _require_creator(program: Program, current_user: User) -> None:
    if program.creator_user_id != current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the program's host can perform this action.",
        )


@router.patch("/programs/{program_id}", response_model=ProgramRead)
def update_program(
    program_id: int,
    payload: ProgramUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProgramRead:
    """Partial update of a program. Only fields set in ``payload`` are touched.
    Host-only: returns 403 if the caller isn't the program's creator."""
    program = _load_program(program_id, db)
    _require_creator(program, current_user)

    # If either datetime is updated, validate the resulting pair is consistent.
    new_start = payload.start_datetime or program.start_datetime
    new_end = payload.end_datetime or program.end_datetime
    if new_end <= new_start:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_datetime must be after start_datetime",
        )

    if (
        payload.category_id is not None
        and db.get(ProgramCategory, payload.category_id) is None
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Category not found"
        )

    if (
        payload.location_id is not None
        and db.get(Location, payload.location_id) is None
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Location not found"
        )

    # Apply only the fields the caller actually set (PATCH semantics). The
    # gallery is replaced separately below, so keep it out of the plain setattr
    # loop (``banner_image_urls`` isn't a column on ``Program``).
    update_fields = payload.model_dump(exclude_unset=True)
    update_fields.pop("banner_image_urls", None)
    for field, value in update_fields.items():
        setattr(program, field, value)

    # Replace the banner gallery when the caller touched either image field.
    # An explicit ``banner_image_urls`` wins (empty list clears the gallery);
    # otherwise a lone ``banner_image_url`` seeds a one-image gallery. Fields the
    # caller left unset don't touch the existing gallery at all.
    fields_set = payload.model_fields_set
    if "banner_image_urls" in fields_set or "banner_image_url" in fields_set:
        if payload.banner_image_urls is not None:
            gallery = payload.banner_image_urls
        elif payload.banner_image_url is not None:
            gallery = [payload.banner_image_url]
        else:
            gallery = []
        db.execute(
            delete(ProgramImage).where(ProgramImage.program_id == program_id)
        )
        for sort_order, url in enumerate(gallery):
            db.add(
                ProgramImage(
                    program_id=program_id,
                    image_url=url,
                    sort_order=sort_order,
                )
            )
        program.banner_image_url = gallery[0] if gallery else None

    # Capacity may have dropped below current occupancy — clamp the FULL flag.
    count = _participant_count(program, db)
    if count < program.max_volunteers and program.status == ProgramStatus.FULL:
        program.status = ProgramStatus.OPEN
    elif count >= program.max_volunteers and program.status == ProgramStatus.OPEN:
        program.status = ProgramStatus.FULL

    db.flush()
    read = ProgramRead.model_validate(program)
    read.participant_count = count
    read.is_full = count >= program.max_volunteers
    _hydrate_images(read, _program_images([program_id], db).get(program_id, []))
    return read


@router.delete(
    "/programs/{program_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_program(
    program_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    """Soft-delete a program. Sets ``is_deleted=True`` so it stops appearing in
    feeds (``_load_program`` filters them out) while keeping the row for audit
    and participation history. Host-only."""
    program = _load_program(program_id, db)
    _require_creator(program, current_user)

    program.is_deleted = True
    program.deleted_at = datetime.now(UTC)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
