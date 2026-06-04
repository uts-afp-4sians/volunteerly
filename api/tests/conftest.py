import asyncio
import os
import tempfile
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

TEST_DB_PATH = Path(tempfile.gettempdir()) / f"volunteerly-api-tests-{os.getpid()}.db"
os.environ["PROJECT_ENV"] = "staging"
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{TEST_DB_PATH}"

from src.lib import all_models  # noqa: E402, F401  (registers all models on Base)
from src.lib.database import Base, async_session_factory, engine  # noqa: E402
from src.main import app  # noqa: E402

if TEST_DB_PATH.exists():
    TEST_DB_PATH.unlink()


@pytest.fixture(autouse=True)
def reset_database() -> Iterator[None]:
    """Reset the SQLite test database and re-seed MockData for each test."""

    async def _reset() -> None:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.drop_all)
            await connection.run_sync(Base.metadata.create_all)
        # Seed the same fixtures the iOS app mocks so contract tests can assert
        # the live API returns identical payloads.
        from scripts.seed import _rows

        async with async_session_factory() as session:
            for row in _rows():
                session.add(row)
            await session.commit()

    asyncio.run(_reset())
    yield


@pytest.fixture
def client() -> Iterator[TestClient]:
    """Test client fixture."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session", autouse=True)
def cleanup_test_database() -> Iterator[None]:
    """Remove the process-local SQLite file after the test session."""
    yield
    asyncio.run(engine.dispose())
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()
