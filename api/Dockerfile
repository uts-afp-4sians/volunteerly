# syntax=docker/dockerfile:1
#
# Multi-stage build with two runtime targets:
#   * local — stdlib pysqlite only, no Rust toolchain (fast; used by compose)
#   * prod  — includes the Turso (libSQL) driver, which compiles a Rust
#             extension; stateless, for hosting on Fly.io against Turso
#
#   docker build --target local .                     # local image
#   docker build --target prod  -t volunteerly-api .  # Turso-capable image
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# uv (package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# ---- deps-local: resolve runtime deps without the Turso extra (no Rust) ----
FROM base AS deps-local
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# ---- deps-turso: same, plus the `turso` extra (compiles libsql via Rust) ----
FROM base AS deps-turso
# libsql-experimental compiles a bundled C SQLite (sqlite3mc) via Rust, which
# needs a full native toolchain: cc/build-essential, cmake, and clang/libclang.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake clang libclang-dev pkg-config curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project --extra turso

# ---- runtime: app code + non-root user (venv supplied by a final stage) ----
FROM base AS runtime
# CA certificates so TLS to Turso (https) works.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY src ./src
COPY alembic ./alembic
COPY alembic.ini .
COPY scripts ./scripts
RUN useradd --create-home --shell /bin/bash appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /app /data
ENV PATH="/app/.venv/bin:${PATH}"
ENV PYTHONPATH=/app
EXPOSE 8000
# Run from the copied venv directly (no `uv run` → no runtime re-sync).
CMD ["fastapi", "run", "src/main.py", "--port", "8000"]

# ---- local: pysqlite, with a /data mount point for a persistent SQLite file --
FROM runtime AS local
COPY --from=deps-local --chown=appuser:appuser /app/.venv /app/.venv
USER appuser
VOLUME /data

# ---- prod: Turso-capable, stateless (Turso is the durable store; no volume) --
FROM runtime AS prod
COPY --from=deps-turso --chown=appuser:appuser /app/.venv /app/.venv
USER appuser
