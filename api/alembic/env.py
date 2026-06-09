from logging.config import fileConfig

from alembic import context
from src.lib import all_models  # noqa: F401  (registers all models on Base)
from src.lib.config import settings
from src.lib.database import Base, engine

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Set sqlalchemy.url from settings
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

target_metadata = Base.metadata

# SQLite (and Turso/libSQL) cannot ALTER most columns in place, so Alembic must
# emit batch operations (copy-and-move) for schema changes.
RENDER_AS_BATCH = settings.DATABASE_URL.startswith("sqlite")


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=RENDER_AS_BATCH,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    Reuse the application's engine (`src.lib.database.engine`) rather than
    building one from the .ini. For Turso/libSQL that engine applies the
    `auth_token` connect-arg workaround the `sqlite+libsql` dialect needs;
    `engine_from_config` would omit it and the connection would 401.
    """
    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=RENDER_AS_BATCH,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
