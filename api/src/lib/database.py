from collections.abc import Generator

from sqlalchemy import URL, MetaData, create_engine, make_url
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import NullPool, Pool

from src.lib.config import settings

# Naming convention for constraints (keeps Alembic autogenerate deterministic)
convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""

    metadata = MetaData(naming_convention=convention)


# Synchronous engine. The app is sync because Turso's libSQL SQLAlchemy driver
# (sqlite+libsql) has no async dialect; FastAPI runs sync routes in a threadpool.
#   * local dev / tests → sqlite:// (stdlib pysqlite)
#   * production        → sqlite+libsql:// (Turso)
def _engine_config(
    url: URL,
) -> tuple[URL, dict[str, object], type[Pool] | None]:
    """Resolve ``(url, connect_args, poolclass)`` for ``create_engine``.

    Kept pure (no settings/engine access) so the pool choice is unit-testable
    without a live database — see ``tests/test_database.py``.
    """
    connect_args: dict[str, object] = {}
    # Default pool is dialect-chosen; only the remote-libsql branch overrides it.
    poolclass: type[Pool] | None = None

    if url.drivername == "sqlite+libsql" and url.host:
        # Remote Turso. The sqlalchemy-libsql 0.2.0 dialect does NOT forward the
        # URL's `authToken` query param to libsql_experimental.connect(), so
        # Turso receives an empty token and rejects the connection (401). Pass
        # it explicitly as `auth_token` and strip it from the URL so the dialect
        # builds a clean https:// URL. (`secure=true` stays, selecting https.)
        auth_token = url.query.get("authToken")
        if auth_token:
            connect_args["auth_token"] = auth_token
            url = url.set(
                query={k: v for k, v in url.query.items() if k != "authToken"}
            )
        # The libsql dialect defaults to StaticPool — a single connection shared
        # by the whole process. FastAPI runs sync routes in a threadpool, so
        # concurrent requests then race on that one libsql connection and the
        # pool raises "can't 'checkout' a detached connection fairy" / "'NoneType'
        # has no attribute 'commit'" intermittently (HTTP 500). NullPool opens a
        # fresh connection per checkout and closes it on return — safe across
        # threads, and cheap because libsql is an HTTP-backed remote DB with no
        # real pool benefit.
        poolclass = NullPool
    elif url.get_backend_name() == "sqlite":
        # Allow pooled SQLite connections to cross FastAPI's threadpool
        # boundaries.
        connect_args["check_same_thread"] = False

    return url, connect_args, poolclass


db_url, connect_args, poolclass = _engine_config(make_url(settings.DATABASE_URL))

engine = create_engine(
    db_url,
    echo=settings.PROJECT_ENV == "local",
    pool_pre_ping=True,
    connect_args=connect_args,
    **({"poolclass": poolclass} if poolclass is not None else {}),
)

# Session factory
session_factory = sessionmaker(
    engine,
    class_=Session,
    expire_on_commit=False,
)


def get_db() -> Generator[Session, None, None]:
    """Dependency for database session injection."""
    with session_factory() as session:
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
