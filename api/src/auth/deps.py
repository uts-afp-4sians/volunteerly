"""Reusable auth dependencies for protecting routes."""

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from src.auth.security import decode_access_token
from src.lib.database import get_db
from src.users.model import User

_bearer = HTTPBearer(auto_error=True)
_optional_bearer = HTTPBearer(auto_error=False)

_CREDENTIALS_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """Resolve the bearer token to a live user, or raise 401."""
    try:
        user_id = decode_access_token(credentials.credentials)
    except jwt.PyJWTError as exc:
        raise _CREDENTIALS_EXCEPTION from exc

    user = db.get(User, user_id)
    if user is None or user.is_deleted:
        raise _CREDENTIALS_EXCEPTION
    return user


def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_optional_bearer),
    db: Session = Depends(get_db),
) -> User | None:
    """Resolve the bearer token to a live user when present, else ``None``.

    Lets a public read still personalise its response (e.g. ``liked_by_me``)
    for a signed-in caller without forcing auth on anonymous reads. A malformed
    or expired token is treated as "no user" rather than an error.
    """
    if credentials is None:
        return None
    try:
        user_id = decode_access_token(credentials.credentials)
    except jwt.PyJWTError:
        return None
    user = db.get(User, user_id)
    if user is None or user.is_deleted:
        return None
    return user
