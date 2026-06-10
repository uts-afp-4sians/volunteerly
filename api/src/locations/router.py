from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user
from src.lib.database import get_db
from src.locations.model import Location
from src.locations.schema import LocationCreate, LocationRead
from src.users.model import User

router = APIRouter(tags=["locations"])


@router.get("/locations", response_model=list[LocationRead])
def list_locations(db: Session = Depends(get_db)) -> list[Location]:
    result = db.execute(select(Location).order_by(Location.location_id))
    return list(result.scalars().all())


@router.post("/locations", response_model=LocationRead)
def create_location(
    payload: LocationCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
) -> Location:
    """Find-or-create a location. Reuses an existing row when city, state and
    country match case-insensitively (backfilling missing coordinates), so the
    table doesn't accumulate duplicates as users pick places on the map."""
    state = payload.state_region.strip() if payload.state_region else None
    stmt = select(Location).where(
        func.lower(Location.city) == payload.city.strip().lower(),
        func.lower(Location.country) == payload.country.strip().lower(),
    )
    if state is None:
        stmt = stmt.where(Location.state_region.is_(None))
    else:
        stmt = stmt.where(func.lower(Location.state_region) == state.lower())

    if existing := db.execute(stmt).scalars().first():
        if existing.latitude is None and payload.latitude is not None:
            existing.latitude = payload.latitude
            existing.longitude = payload.longitude
            db.flush()
        return existing

    location = Location(
        city=payload.city.strip(),
        state_region=state,
        country=payload.country.strip(),
        latitude=payload.latitude,
        longitude=payload.longitude,
    )
    db.add(location)
    try:
        db.flush()
    except IntegrityError:
        # Lost a find-or-create race: another request inserted the same place
        # between our SELECT and INSERT (uq_locations_city_state_country).
        # Roll back the failed insert and return the surviving row.
        db.rollback()
        if survivor := db.execute(stmt).scalars().first():
            return survivor
        raise
    return location


@router.get("/locations/{location_id}", response_model=LocationRead)
def get_location(location_id: int, db: Session = Depends(get_db)) -> Location:
    location = db.get(Location, location_id)
    if location is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Location not found"
        )
    return location
