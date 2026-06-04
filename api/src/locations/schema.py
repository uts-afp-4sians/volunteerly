from pydantic import BaseModel, ConfigDict


class LocationRead(BaseModel):
    """Wire shape matching iOS `Location`."""

    model_config = ConfigDict(from_attributes=True)

    location_id: int
    city: str
    state_region: str | None = None
    country: str
    latitude: float | None = None
    longitude: float | None = None
