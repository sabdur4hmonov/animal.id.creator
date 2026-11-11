from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://biolivestock:biolivestock@localhost:5432/biolivestock"
    species_config_dir: Path = ROOT / "species_configs"
    model_root: Path = ROOT
    storage_root: Path = ROOT / "data"
    auth_config_path: Path = ROOT / "backend" / ".secrets" / "api_keys.json"
    business_config_dir: Path = ROOT / "business_configs"
    security_config_dir: Path = ROOT / "security_configs"
    max_upload_bytes: int = Field(default=15 * 1024 * 1024, gt=0)
    max_image_pixels: int = Field(default=25_000_000, gt=0)
    public_origin: str = Field(default="", max_length=512)
    public_token_bytes: int = Field(default=32, ge=32, le=64)
    public_rate_requests: int = Field(default=30, ge=1, le=1000)
    public_rate_window_seconds: int = Field(default=60, ge=1, le=3600)
    qr_box_size: int = Field(default=8, ge=4, le=20)
    qr_border: int = Field(default=4, ge=4, le=10)


@lru_cache
def get_settings() -> Settings:
    return Settings()
