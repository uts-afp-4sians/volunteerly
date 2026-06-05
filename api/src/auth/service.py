"""Auth business logic: registration and credential verification.

Sits between the router (HTTP) and the ORM. Raises domain-meaningful
``AuthError`` subclasses; the router maps them to HTTP responses.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from src.auth.schema import RegisterRequest
from src.auth.security import hash_password, verify_password
from src.users.model import User, UserProfile


class AuthError(Exception):
    """Base class for auth failures the router translates to HTTP errors."""


class EmailAlreadyRegistered(AuthError):
    """Registration attempted with an email that already exists."""


class InvalidCredentials(AuthError):
    """Login failed: unknown email, wrong password, or deleted account."""


def register_user(db: Session, payload: RegisterRequest) -> User:
    """Create a new user + profile, or raise ``EmailAlreadyRegistered``."""
    existing = db.execute(
        select(User).where(User.email == payload.email)
    ).scalar_one_or_none()
    if existing is not None:
        raise EmailAlreadyRegistered

    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.flush()  # assign user.user_id before creating the dependent profile

    db.add(
        UserProfile(
            user_id=user.user_id,
            first_name=payload.first_name,
            last_name=payload.last_name,
        )
    )
    db.flush()
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    """Return the user for valid credentials, or raise ``InvalidCredentials``."""
    user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()

    # Verify even when the user is missing to keep timing uniform, then reject
    # missing/deleted/passwordless accounts uniformly as "invalid credentials".
    stored_hash = user.password_hash if user else None
    password_ok = verify_password(password, stored_hash) if stored_hash else False

    if user is None or user.is_deleted or not password_ok:
        raise InvalidCredentials
    return user
