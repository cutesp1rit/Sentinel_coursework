from typing import List, Union
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Sentinel API"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "Интеллектуальный тайм-менеджер API"
    
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    
    DATABASE_URL: str
    DATABASE_SYNC_URL: str
    
    BACKEND_CORS_ORIGINS: List[AnyHttpUrl] = []
    
    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
    LLM_API_KEY: str = ""
    LLM_MODEL: str = ""
    LLM_REBALANCE_MODEL: str = ""  # falls back to LLM_MODEL if not set
    LLM_BASE_URL: str = ""
    LLM_HISTORY_LIMIT: int = 20
    LLM_VISION_ENABLED: bool = True

    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAILS_FROM: str = "noreply@sentinel.app"
    EMAILS_FROM_NAME: str = "Sentinel"

    REQUIRE_EMAIL_VERIFICATION: bool = True
    EMAIL_VERIFICATION_EXPIRE_HOURS: int = 24
    PASSWORD_RESET_EXPIRE_HOURS: int = 1

    FRONTEND_URL: str = "http://localhost:3000"

    MAX_FILE_SIZE: int = 10 * 1024 * 1024
    ALLOWED_IMAGE_EXTENSIONS: List[str] = ["png", "jpg", "jpeg", "heic"]
    ALLOWED_DOCUMENT_EXTENSIONS: List[str] = ["pdf", "docx", "txt", "csv", "md", "pptx", "xlsx", "json"]
    
    S3_BUCKET_NAME: str = ""
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: str = ""
    S3_REGION: str = "auto"
    S3_ENDPOINT_URL: str = ""   # https://<account_id>.r2.cloudflarestorage.com
    S3_PUBLIC_URL: str = ""     # https://pub-xxx.r2.dev  (public bucket URL, для браузера)
    
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()