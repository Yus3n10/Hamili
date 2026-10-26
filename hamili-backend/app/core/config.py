"""
Central application configuration.

All environment-dependent values are read once here and reused across the
app. This is the ONLY place that should call os.environ / read .env files,
so swapping deployment environments never means hunting through the codebase.
"""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str

    @field_validator("database_url")
    @classmethod
    def _normalize_database_url(cls, value: str) -> str:
        if value.startswith("postgres://"):
            return "postgresql+psycopg2://" + value[len("postgres://") :]
        if value.startswith("postgresql://"):
            return "postgresql+psycopg2://" + value[len("postgresql://") :]
        return value

    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    ai_provider: str = "gemini"
    gemini_api_key: str = ""

    app_timezone: str = "Asia/Manila"

    # Comma-separated user ids allowed into the admin console. Ids, not
    # emails, because anyone can register an unclaimed email.
    admin_user_ids: str = ""

    environment: str = "development"
    cors_origins: str = "http://localhost:3000"

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)

    @property
    def admin_id_set(self) -> set[int]:
        return {int(part) for part in (p.strip() for p in self.admin_user_ids.split(",")) if part.isdigit()}

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",")]


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance — env is only parsed once per process."""
    return Settings()
