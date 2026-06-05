"""Regression guard for Alembic migration drift.

Production returned 500 on every `/programs` endpoint because the migration
adding `programs.commitment_frequency` / `commitment_duration` was never applied
to the live DB (Render's free plan ran no migration step on deploy). The tests
build a fresh database *through migrations* — not `Base.metadata.create_all`,
which the conftest fixture uses — and assert the schema the code expects is
actually produced by `alembic upgrade head`.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from sqlalchemy import create_engine, inspect

# api/ — the dir holding alembic.ini, and the import root for `src`.
API_DIR = Path(__file__).resolve().parent.parent


def _migrate_fresh_db() -> str:
    """Run `alembic upgrade head` against a throwaway SQLite DB and return its URL.

    A subprocess is used so Alembic's ``env.py`` reads this disposable
    ``DATABASE_URL`` at import time, isolated from the test DB managed by the
    autouse ``reset_database`` fixture in the same process.
    """
    db_path = Path(tempfile.mkdtemp()) / "migration-check.db"
    db_url = f"sqlite:///{db_path}"
    subprocess.run(
        [sys.executable, "-c", "from alembic.config import main; main(['upgrade', 'head'])"],
        cwd=API_DIR,
        env={**os.environ, "DATABASE_URL": db_url, "PROJECT_ENV": "staging"},
        check=True,
        capture_output=True,
    )
    return db_url


def test_migrations_create_programs_commitment_columns() -> None:
    engine = create_engine(_migrate_fresh_db())
    try:
        columns = {col["name"] for col in inspect(engine).get_columns("programs")}
    finally:
        engine.dispose()

    assert {"commitment_frequency", "commitment_duration"} <= columns, (
        "alembic upgrade head did not produce the commitment columns the "
        f"Program model selects; got: {sorted(columns)}"
    )
