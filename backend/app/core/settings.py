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
    max_upload_bytes: int = Field(default=15 * 1024 * 1024, gt=0)
    max_image_pixels: int = Field(default=25_000_000, gt=0)


@lru_cache
def get_settings() -> Settings:
    return Settings()
