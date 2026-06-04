# volunteerly-api

FastAPI backend for Volunteerly.

**Stack:** FastAPI · SQLAlchemy 2.0 · Alembic · Pydantic Settings ·
structlog · uv · ruff · mypy · pytest. Managed with [mise](https://mise.jdx.dev/)
and [poe](https://poethepoet.natn.io/).

**Database:** SQLite via [Turso](https://turso.tech) (libSQL) in production, and a
local SQLite file (stdlib pysqlite) for development and tests. Same SQL dialect
both places — only `DATABASE_URL` changes. The app is synchronous because Turso's
libSQL SQLAlchemy driver has no async dialect (FastAPI runs sync routes in a
threadpool).

## Prerequisites

- [mise](https://mise.jdx.dev/) (installs Python 3.12 + uv for you), or
- Python 3.12 + [uv](https://docs.astral.sh/uv/) directly.

## Setup

```bash
cd api
cp .env.example .env          # local defaults work out of the box
mise run install              # or: uv sync
```

## Develop

```bash
mise run dev                  # http://localhost:8000  (docs at /docs)
```

Health check: `curl http://localhost:8000/health`

## Database migrations

```bash
mise run "migrate:create" -- "create users table"   # autogenerate a revision
mise run migrate                                     # apply migrations
```

Migrations run in Alembic **batch mode** automatically (SQLite/libSQL can't
`ALTER` columns in place).

### Pointing at Turso (production)

Create a Turso database, then set in your environment:

```
DATABASE_URL=sqlite+libsql://your-db-name.turso.io/?authToken=YOUR_TOKEN&secure=true
```

## Quality

```bash
mise run lint        # ruff --fix
mise run format      # ruff format
mise run typecheck   # mypy (strict)
mise run test        # pytest
```

## Layout

```
src/
├── main.py              # app, middleware, health routes
├── lib/                 # config, database, logging
├── common/models/       # shared mixins + pagination
└── users/               # example feature (model)
alembic/                 # migrations
tests/                   # pytest
```

Add a feature as `src/<feature>/` with `model.py` / `router.py`, then register the
router in `src/main.py`.
