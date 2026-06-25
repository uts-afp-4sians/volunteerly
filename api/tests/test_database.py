"""Engine/pool configuration regression tests.

Guards the fix for the intermittent HTTP 500s ("can't 'checkout' a detached
connection fairy" / "'NoneType' object has no attribute 'commit'") that broke
bookmarking and other endpoints: the libsql dialect defaults to StaticPool — a
single connection the whole process shares — which races under FastAPI's
threadpool. Remote libsql must use NullPool instead.
"""

from sqlalchemy import make_url
from sqlalchemy.pool import NullPool

from src.lib.database import _engine_config


def test_remote_libsql_uses_nullpool_not_staticpool() -> None:
    url = make_url("sqlite+libsql://db.turso.io/?authToken=secret&secure=true")

    resolved_url, connect_args, poolclass = _engine_config(url)

    # NullPool gives every checkout its own connection — never shared across the
    # threadpool. StaticPool (the dialect default) is what caused the 500s.
    assert poolclass is NullPool
    # The auth token moves to connect_args and is stripped from the URL.
    assert connect_args["auth_token"] == "secret"  # noqa: S105
    assert "authToken" not in resolved_url.query


def test_local_sqlite_keeps_dialect_pool_and_allows_threadpool() -> None:
    url = make_url("sqlite:///./dev.db")

    _resolved_url, connect_args, poolclass = _engine_config(url)

    # Local file SQLite keeps the dialect's default pool; only needs the
    # cross-thread checkout flag.
    assert poolclass is None
    assert connect_args["check_same_thread"] is False
