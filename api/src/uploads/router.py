from fastapi import APIRouter, Depends

from src.auth.deps import get_current_user
from src.uploads.schema import PresignResponse, UploadKind
from src.uploads.service import generate_presigned_url
from src.users.model import User

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/presign", response_model=PresignResponse)
def presign(
    kind: UploadKind,
    program_id: int | None = None,
    current_user: User = Depends(get_current_user),
) -> PresignResponse:
    """Return a presigned PUT URL for uploading an image to Cloudflare R2."""
    return generate_presigned_url(
        kind=kind,
        user_id=current_user.user_id,
        program_id=program_id,
    )
