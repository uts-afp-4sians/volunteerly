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
    # Local dev: sqlite+aiosqlite:///./dev.db
    # Production (Turso): sqlite+libsql://<db>.turso.io/?authToken=...&secure=true
    DATABASE_URL: str = "sqlite+aiosqlite:///./dev.db"

    # CORS
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance."""
    return Settings()


settings = get_settings()
