"""Shared wire-format helpers for response schemas."""

from datetime import UTC, datetime
from typing import Annotated

from pydantic import PlainSerializer


def _to_iso8601_z(dt: datetime) -> str:
    """Serialize a datetime as RFC3339 / ISO8601 with a UTC ``Z`` suffix.

    SQLite stores datetimes timezone-naive, so values read back have no tzinfo.
    iOS decodes dates with ``JSONDecoder.dateDecodingStrategy = .iso8601``, which
    *requires* a timezone designator — a naive ``2026-07-01T08:00:00`` would fail
    to decode. We assume stored datetimes are UTC and emit e.g.
    ``2026-07-01T08:00:00Z``.
    """
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC).isoformat().replace("+00:00", "Z")


# Use in response schemas in place of `datetime` so every timestamp the iOS app
# decodes carries a UTC `Z` offset.
UTCDateTime = Annotated[
    datetime,
    PlainSerializer(_to_iso8601_z, return_type=str, when_used="json"),
]
