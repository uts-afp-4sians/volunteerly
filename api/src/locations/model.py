from sqlalchemy import Float, Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from src.lib.database import Base


class Location(Base):
    """A geographic location (LOCATION)."""

    __tablename__ = "locations"

    location_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    city: Mapped[str] = mapped_column(String(255))
    state_region: Mapped[str | None] = mapped_column(String(255), nullable=True)
    country: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)


# Enforces find-or-create dedup at the schema level: two concurrent
# POST /locations for the same place race past the SELECT, but the second
# INSERT hits this index and the router falls back to the surviving row.
# NULL state_region coalesces to '' so "Paris, France" can't exist twice.
Index(
    "uq_locations_city_state_country",
    func.lower(Location.city),
    func.lower(func.coalesce(Location.state_region, "")),
    func.lower(Location.country),
    unique=True,
)
