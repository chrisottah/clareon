from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_ENV: str = "development"
    SECRET_KEY: str = "change-me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    HUGGINGFACE_TOKEN: str = ""

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://clareon:clareon_secret@db:5432/clareon_db"

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    # Email - Brevo API
    BREVO_API_KEY: str = ""
    SMTP_HOST: str = "smtp-relay.brevo.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAILS_FROM_NAME: str = "Clareon"
    EMAILS_FROM_EMAIL: str = "noreply@clareon.online"

    # Storage
    MEDIA_DIR: str = "/app/media"

    # Groq
    GROQ_API_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()