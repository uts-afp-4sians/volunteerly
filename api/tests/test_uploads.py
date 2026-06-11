"""Unit tests for the Cloudflare R2 uploads module.

Covers:
- generate_presigned_url local fallback (no R2 keys)
- generate_presigned_url with mocked boto3 client
- program_banner key format when program_id is None
- HTTP endpoint authentication guard
- HTTP endpoint fallback response shape
- HTTP endpoint validation of invalid kind value
"""

from collections.abc import Generator
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from src.lib import config as config_module
from src.uploads.schema import PresignResponse, UploadKind
from src.uploads.service import _r2_client, generate_presigned_url

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _login(client: TestClient) -> str:
    """Return a valid Bearer token for the seeded jane.doe user."""
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    return res.json()["token"]


# ---------------------------------------------------------------------------
# MARK: 1. Local fallback -- no R2 keys
# ---------------------------------------------------------------------------


def test_fallback_profile_image_returns_empty_response() -> None:
    """When R2_ACCESS_KEY_ID is empty, generate_presigned_url returns empty strings."""
    assert config_module.settings.R2_ACCESS_KEY_ID == ""

    result = generate_presigned_url(kind=UploadKind.profile_image, user_id=1)

    assert isinstance(result, PresignResponse)
    assert result.upload_url == ""
    assert result.public_url == ""
    assert result.expires_in == 0


def test_fallback_program_banner_returns_empty_response() -> None:
    """When R2_ACCESS_KEY_ID is empty, program_banner also returns the fallback."""
    assert config_module.settings.R2_ACCESS_KEY_ID == ""

    result = generate_presigned_url(
        kind=UploadKind.program_banner, user_id=1, program_id=42
    )

    assert isinstance(result, PresignResponse)
    assert result.upload_url == ""
    assert result.public_url == ""
    assert result.expires_in == 0


# ---------------------------------------------------------------------------
# MARK: 2. Presign with real credentials -- boto3 mocked
# ---------------------------------------------------------------------------


@pytest.fixture
def r2_settings(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    """Patch settings with R2 credentials and clear the lru_cache."""
    monkeypatch.setattr(config_module.settings, "R2_ACCESS_KEY_ID", "test-key-id")
    monkeypatch.setattr(
        config_module.settings, "R2_SECRET_ACCESS_KEY", "test-secret-key"
    )
    monkeypatch.setattr(config_module.settings, "R2_ACCOUNT_ID", "test-account")
    monkeypatch.setattr(config_module.settings, "R2_BUCKET", "test-bucket")
    monkeypatch.setattr(
        config_module.settings, "R2_PUBLIC_URL", "https://pub-test.r2.dev"
    )
    _r2_client.cache_clear()
    yield
    _r2_client.cache_clear()


def _extract_call_params(mock_client: MagicMock) -> dict:
    """Extract the Params dict from the boto3 generate_presigned_url call."""
    call_kwargs = mock_client.generate_presigned_url.call_args
    if call_kwargs.kwargs:
        return call_kwargs.kwargs["Params"]
    return call_kwargs.args[1]["Params"]


def _extract_expires_in(mock_client: MagicMock) -> int:
    """Extract the ExpiresIn value from the boto3 generate_presigned_url call."""
    call_kwargs = mock_client.generate_presigned_url.call_args
    if call_kwargs.kwargs:
        return call_kwargs.kwargs["ExpiresIn"]
    return call_kwargs.args[1]["ExpiresIn"]


def test_presign_profile_image_key_format(r2_settings: None) -> None:
    """profile_image key is profile_image/{user_id}/{uuid}.webp."""
    fake_url = "https://fake-presigned-url.example.com/upload"
    mock_client = MagicMock()
    mock_client.generate_presigned_url.return_value = fake_url

    with patch("src.uploads.service.boto3.client", return_value=mock_client):
        _r2_client.cache_clear()
        result = generate_presigned_url(kind=UploadKind.profile_image, user_id=7)

    assert result.upload_url == fake_url
    assert result.expires_in == 300

    params = _extract_call_params(mock_client)
    key: str = params["Key"]
    parts = key.split("/")
    assert parts[0] == "profile_image"
    assert parts[1] == "7"
    assert parts[2].endswith(".webp")

    assert result.public_url.startswith("https://pub-test.r2.dev/")
    assert result.public_url == f"https://pub-test.r2.dev/{key}"


def test_presign_program_banner_key_format(r2_settings: None) -> None:
    """program_banner key is program_banner/{user_id}/{program_id}/{uuid}.webp."""
    fake_url = "https://fake-presigned-url.example.com/upload"
    mock_client = MagicMock()
    mock_client.generate_presigned_url.return_value = fake_url

    with patch("src.uploads.service.boto3.client", return_value=mock_client):
        _r2_client.cache_clear()
        result = generate_presigned_url(
            kind=UploadKind.program_banner, user_id=7, program_id=99
        )

    params = _extract_call_params(mock_client)
    key: str = params["Key"]
    parts = key.split("/")
    assert parts[0] == "program_banner"
    assert parts[1] == "7"
    assert parts[2] == "99"
    assert parts[3].endswith(".webp")

    assert result.expires_in == 300
    assert result.public_url == f"https://pub-test.r2.dev/{key}"


def test_presign_content_type_is_webp(r2_settings: None) -> None:
    """ContentType image/webp is passed to generate_presigned_url Params."""
    mock_client = MagicMock()
    mock_client.generate_presigned_url.return_value = "https://example.com/url"

    with patch("src.uploads.service.boto3.client", return_value=mock_client):
        _r2_client.cache_clear()
        generate_presigned_url(kind=UploadKind.profile_image, user_id=1)

    params = _extract_call_params(mock_client)
    assert params["ContentType"] == "image/webp"


def test_presign_expires_in_300(r2_settings: None) -> None:
    """ExpiresIn=300 is passed to the boto3 call and returned in the response."""
    mock_client = MagicMock()
    mock_client.generate_presigned_url.return_value = "https://example.com/url"

    with patch("src.uploads.service.boto3.client", return_value=mock_client):
        _r2_client.cache_clear()
        result = generate_presigned_url(kind=UploadKind.profile_image, user_id=1)

    expires_in = _extract_expires_in(mock_client)
    assert expires_in == 300
    assert result.expires_in == 300


# ---------------------------------------------------------------------------
# MARK: 3. program_banner with None program_id uses segment "0"
# ---------------------------------------------------------------------------


def test_program_banner_none_program_id_uses_zero(r2_settings: None) -> None:
    """When program_id is None, the key segment defaults to 0."""
    mock_client = MagicMock()
    mock_client.generate_presigned_url.return_value = "https://example.com/url"

    with patch("src.uploads.service.boto3.client", return_value=mock_client):
        _r2_client.cache_clear()
        generate_presigned_url(
            kind=UploadKind.program_banner, user_id=5, program_id=None
        )

    params = _extract_call_params(mock_client)
    key: str = params["Key"]
    parts = key.split("/")
    # program_banner/{user_id}/{program_id}/{filename}
    assert parts[2] == "0"


# ---------------------------------------------------------------------------
# MARK: 4. HTTP endpoint -- unauthenticated returns 401
# ---------------------------------------------------------------------------


def test_presign_endpoint_unauthenticated(client: TestClient) -> None:
    """POST /uploads/presign without a Bearer token returns 401."""
    res = client.post("/uploads/presign?kind=profile_image")
    assert res.status_code == 401


# ---------------------------------------------------------------------------
# MARK: 5. HTTP endpoint -- authenticated, fallback environment returns 200
# ---------------------------------------------------------------------------


def test_presign_endpoint_authenticated_fallback(client: TestClient) -> None:
    """Authenticated request returns 200 with empty fallback payload when no R2 keys."""
    assert config_module.settings.R2_ACCESS_KEY_ID == ""

    token = _login(client)
    res = client.post(
        "/uploads/presign?kind=profile_image",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert res.status_code == 200
    body = res.json()
    assert body == {"upload_url": "", "public_url": "", "expires_in": 0}


# ---------------------------------------------------------------------------
# MARK: 6. HTTP endpoint -- invalid kind returns 422
# ---------------------------------------------------------------------------


def test_presign_endpoint_invalid_kind(client: TestClient) -> None:
    """POST /uploads/presign?kind=invalid_kind returns 422 Unprocessable Entity."""
    token = _login(client)
    res = client.post(
        "/uploads/presign?kind=invalid_kind",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 422
