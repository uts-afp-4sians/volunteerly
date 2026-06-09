from enum import StrEnum

from pydantic import BaseModel


class UploadKind(StrEnum):
    profile_image = "profile_image"
    program_banner = "program_banner"


class PresignResponse(BaseModel):
    upload_url: str
    public_url: str
    expires_in: int
