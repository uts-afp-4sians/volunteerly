from collections.abc import Generator

from sqlalchemy import MetaData, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

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
connect_args: dict[str, object] = {}
if settings.DATABASE_URL.startswith(("sqlite://", "sqlite+pysqlite")):
    # Allow pooled SQLite connections to cross FastAPI's threadpool boundaries.
    connect_args["check_same_thread"] = False

engine = create_engine(
    settings.DATABASE_URL,
    echo=settings.PROJECT_ENV == "local",
    pool_pre_ping=True,
    connect_args=connect_args,
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
