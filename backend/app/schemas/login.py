from pydantic import Field, field_validator

from app.schemas.common import StrictInput


class LoginInput(StrictInput):
    username: str = Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")
    password: str = Field(min_length=1, max_length=256)

    @field_validator("username")
    @classmethod
    def normalize(cls, value):
        return value.lower()
