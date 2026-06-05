from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # Project
    PROJECT_NAME: str = "volunteerly-api"
    PROJECT_ENV: Literal["local", "staging", "prod"] = "local"

    # Database
    # Local dev: sqlite:///./dev.db  (stdlib pysqlite)
    # Production (Turso): sqlite+libsql://<db>.turso.io/?authToken=...&secure=true
    DATABASE_URL: str = "sqlite:///./dev.db"

    # CORS
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]

    # Auth / JWT
    # The default is a throwaway dev secret. Production MUST override JWT_SECRET
    # with a long random value (e.g. `openssl rand -hex 32`) via the environment.
    JWT_SECRET: str = "dev-insecure-change-me-0000000000-not-for-production"  # noqa: S105
    JWT_ALGORITHM: str = "HS256"
    # Access-token lifetime. iOS persists the token in UserDefaults and only
    # clears it on logout, so a week-long window matches the client's session.
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance."""
    return Settings()


settings = get_settings()
