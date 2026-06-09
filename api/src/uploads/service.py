from functools import lru_cache
from uuid import uuid4

import boto3

from src.lib.config import settings
from src.uploads.schema import PresignResponse, UploadKind

_PRESIGN_EXPIRES_IN = 300


@lru_cache(maxsize=1)
def _r2_client() -> "boto3.client":  # type: ignore[name-defined]
    """Return a cached boto3 S3 client configured for Cloudflare R2."""
    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        region_name="auto",
    )


def generate_presigned_url(
    kind: UploadKind,
    user_id: int,
    program_id: int | None = None,
) -> PresignResponse:
    """Generate a presigned PUT URL for uploading an image to Cloudflare R2.

    Returns a PresignResponse with an empty upload_url when R2 credentials are
    not configured (local / test environments).
    """
    # TODO(oma-deferred): integrate R2 when key is provisioned
    if not settings.R2_ACCESS_KEY_ID:
        return PresignResponse(upload_url="", public_url="", expires_in=0)

    filename = f"{uuid4().hex}.webp"

    if kind == UploadKind.profile_image:
        object_key = f"profile_image/{user_id}/{filename}"
    else:
        resolved_program_id = program_id if program_id is not None else 0
        object_key = f"program_banner/{user_id}/{resolved_program_id}/{filename}"

    client = _r2_client()
    upload_url: str = client.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.R2_BUCKET,
            "Key": object_key,
            "ContentType": "image/webp",
        },
        ExpiresIn=_PRESIGN_EXPIRES_IN,
    )

    public_url = f"{settings.R2_PUBLIC_URL.rstrip('/')}/{object_key}"

    return PresignResponse(
        upload_url=upload_url,
        public_url=public_url,
        expires_in=_PRESIGN_EXPIRES_IN,
    )
