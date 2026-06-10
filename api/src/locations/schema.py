from pydantic import BaseModel, ConfigDict, Field


class LocationCreate(BaseModel):
    """Body for ``POST /locations`` — find-or-create a location picked on the
    client's map. Matching is case-insensitive on city/state/country."""

    city: str = Field(min_length=1, max_length=255)
    state_region: str | None = Field(default=None, max_length=255)
    country: str = Field(min_length=1, max_length=255)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class LocationRead(BaseModel):
    """Wire shape matching iOS `Location`."""

    model_config = ConfigDict(from_attributes=True)

    location_id: int
    city: str
    state_region: str | None = None
    country: str
    latitude: float | None = None
    longitude: float | None = None
