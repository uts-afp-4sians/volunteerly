from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.lib.database import get_db
from src.locations.model import Location
from src.locations.schema import LocationRead

router = APIRouter(tags=["locations"])


@router.get("/locations", response_model=list[LocationRead])
def list_locations(db: Session = Depends(get_db)) -> list[Location]:
    result = db.execute(select(Location).order_by(Location.location_id))
    return list(result.scalars().all())


@router.get("/locations/{location_id}", response_model=LocationRead)
def get_location(location_id: int, db: Session = Depends(get_db)) -> Location:
    location = db.get(Location, location_id)
    if location is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Location not found"
        )
    return location
