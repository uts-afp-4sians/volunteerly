from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from typing import Literal
from uuid import uuid4

import structlog
from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import text

from src.lib.config import settings
from src.lib.database import engine, session_factory
from src.lib.logging import configure_logging, get_logger

# Configure logging first
configure_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Application lifespan handler for startup/shutdown events."""
    logger.info("Starting application", env=settings.PROJECT_ENV)
    # Micro-migration: databases seeded before the locations dedup index
    # existed don't get it from create_all (which skips existing tables).
    # Mirrors uq_locations_city_state_country in src/locations/model.py.
    try:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "CREATE UNIQUE INDEX IF NOT EXISTS "
                    "uq_locations_city_state_country ON locations "
                    "(lower(city), lower(coalesce(state_region, '')), lower(country))"
                )
            )
    except Exception:
        # Most likely pre-existing duplicate rows; dedupe manually, then restart.
        logger.warning("could not ensure locations unique index", exc_info=True)
    yield
    logger.info("Shutting down application")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.PROJECT_ENV != "prod" else None,
    redoc_url="/redoc" if settings.PROJECT_ENV != "prod" else None,
)


@app.middleware("http")
async def request_id_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """Add a request ID to each request for tracing/correlation."""
    request_id = request.headers.get("X-Request-ID", str(uuid4()))
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(request_id=request_id)

    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


class ErrorResponse(BaseModel):
    """Standard error response format."""

    error: str
    message: str
    request_id: str | None = None


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle all unhandled exceptions with a consistent format."""
    request_id = request.headers.get("X-Request-ID")
    logger.exception(
        "Unhandled exception",
        exc_info=exc,
        request_id=request_id,
        path=request.url.path,
        method=request.method,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=ErrorResponse(
            error="internal_server_error",
            message="An unexpected error occurred"
            if settings.PROJECT_ENV == "prod"
            else str(exc),
            request_id=request_id,
        ).model_dump(),
    )


# Human-readable copy for the fields a client form can actually correct. The
# raw pydantic messages ("value is not a valid email address: ...") are too
# noisy to drop straight into a sign-up form, so map the known ones; anything
# unmapped falls back to the pydantic message.
_FRIENDLY_FIELD_MESSAGES: dict[str, str] = {
    "email": "Enter a valid email address.",
    "password": "Password must be at least 8 characters.",
    "first_name": "First name is required.",
    "last_name": "Last name is required.",
}


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """Return a flat, field-keyed 422 the mobile form can render inline.

    FastAPI's default 422 body nests a `detail` list of pydantic errors that is
    awkward to surface in UI. We collapse it to `{field: message}` and log the
    offending field names (never the values, so passwords don't leak).
    """
    request_id = request.headers.get("X-Request-ID")
    fields: dict[str, str] = {}
    for err in exc.errors():
        # loc looks like ("body", "email"); the field is the last path segment.
        loc = [str(part) for part in err.get("loc", ()) if part != "body"]
        field = loc[-1] if loc else "body"
        fields.setdefault(
            field,
            _FRIENDLY_FIELD_MESSAGES.get(field, err.get("msg", "Invalid value.")),
        )

    logger.warning(
        "Request validation failed",
        request_id=request_id,
        path=request.url.path,
        method=request.method,
        fields=list(fields.keys()),
    )
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "validation_error",
            "message": "Some details need your attention.",
            "fields": fields,
            "request_id": request_id,
        },
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ServiceStatus(BaseModel):
    """Individual service health status."""

    status: Literal["healthy", "unhealthy"]
    latency_ms: float | None = None
    error: str | None = None


class HealthResponse(BaseModel):
    """Health check response with detailed service statuses."""

    status: Literal["healthy", "degraded", "unhealthy"]
    version: str = "0.1.0"
    services: dict[str, ServiceStatus]


def check_database() -> ServiceStatus:
    """Check database connectivity."""
    import time

    start = time.perf_counter()
    try:
        with session_factory() as session:
            session.execute(text("SELECT 1"))
        latency = (time.perf_counter() - start) * 1000
        return ServiceStatus(status="healthy", latency_ms=round(latency, 2))
    except Exception as e:
        latency = (time.perf_counter() - start) * 1000
        return ServiceStatus(
            status="unhealthy", latency_ms=round(latency, 2), error=str(e)
        )


@app.get("/health")
def health_check() -> HealthResponse:
    """Detailed health check endpoint with service statuses."""
    services: dict[str, ServiceStatus] = {"database": check_database()}

    statuses = [s.status for s in services.values()]
    if all(s == "healthy" for s in statuses):
        overall_status: Literal["healthy", "degraded", "unhealthy"] = "healthy"
    elif all(s == "unhealthy" for s in statuses):
        overall_status = "unhealthy"
    else:
        overall_status = "degraded"

    return HealthResponse(status=overall_status, version="0.1.0", services=services)


@app.get("/health/live")
async def liveness_check() -> dict[str, str]:
    """Simple liveness probe."""
    return {"status": "ok"}


@app.get("/health/ready")
def readiness_check() -> dict[str, str]:
    """Readiness probe - checks if the app can serve traffic."""
    db_status = check_database()
    if db_status.status == "unhealthy":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database not ready",
        )
    return {"status": "ready"}


# Feature routers. Paths are root-level to match the iOS HTTPClient contract
# (e.g. GET /programs, GET /users/{id}) — see Core/Networking/MockData.swift.
# Import every ORM model so Base.metadata is complete before any flush. Some
# tables (e.g. `locations`) have no router and would otherwise be missing,
# breaking FK resolution for related inserts like UserProfile.
from src.auth.router import router as auth_router  # noqa: E402
from src.categories.router import router as categories_router  # noqa: E402
from src.forum.router import router as forum_router  # noqa: E402
from src.lib import all_models  # noqa: E402, F401
from src.locations.router import router as locations_router  # noqa: E402
from src.programs.router import router as programs_router  # noqa: E402
from src.uploads.router import router as uploads_router  # noqa: E402
from src.users.router import router as users_router  # noqa: E402

app.include_router(auth_router)
app.include_router(programs_router)
app.include_router(forum_router)
app.include_router(users_router)
app.include_router(categories_router)
app.include_router(locations_router)
app.include_router(uploads_router)
