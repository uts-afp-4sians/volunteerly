"""Regression guard for DATABASE_URL parsing.

The migrate CI died with "Could not parse SQLAlchemy URL" because the injected
``DATABASE_URL`` secret carried wrapping quotes / a leading space. Settings now
sanitizes the value so ``make_url`` accepts it.
"""

import pytest
from sqlalchemy.engine.url import make_url

from src.lib.config import Settings

CLEAN = "sqlite+libsql://db.turso.io/?authToken=abc&secure=true"


@pytest.mark.parametrize(
    "raw",
    [
        CLEAN,
        f'"{CLEAN}"',  # double-quoted (common .env paste)
        f"'{CLEAN}'",  # single-quoted
        f"  {CLEAN}",  # leading whitespace
        f"{CLEAN}\n",  # trailing newline
    ],
)
def test_database_url_is_sanitized(raw: str) -> None:
    settings = Settings(DATABASE_URL=raw)
    assert settings.DATABASE_URL == CLEAN
    # The whole point: make_url must accept the cleaned value.
    assert make_url(settings.DATABASE_URL).get_backend_name() == "sqlite"
