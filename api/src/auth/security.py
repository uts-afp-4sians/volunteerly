"""Password hashing (bcrypt) and access-token (JWT) primitives.

Pure functions with no DB or HTTP knowledge so they stay easy to unit-test and
reuse. Business decisions (who may log in, what a token contains) live in the
service layer.
"""

from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
import jwt

from src.lib.config import settings

# bcrypt hashes at most the first 72 bytes of input; longer passwords are
# silently truncated by the algorithm. We reject them at the schema layer
# (RegisterRequest.password max_length) so behaviour is explicit, not silent.
_BCRYPT_MAX_BYTES = 72


def hash_password(password: str) -> str:
    """Return a salted bcrypt hash for ``password``."""
    pwd = password.encode("utf-8")[:_BCRYPT_MAX_BYTES]
    return bcrypt.hashpw(pwd, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    """Check ``password`` against a stored bcrypt ``password_hash``."""
    pwd = password.encode("utf-8")[:_BCRYPT_MAX_BYTES]
    try:
        return bcrypt.checkpw(pwd, password_hash.encode("utf-8"))
    except ValueError:
        # Malformed/empty stored hash — treat as a non-match, never raise.
        return False


def create_access_token(user_id: int) -> str:
    """Issue a signed JWT whose subject is the user id."""
    now = datetime.now(UTC)
    expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> int:
    """Validate a JWT and return the user id, or raise ``jwt.PyJWTError``."""
    payload = jwt.decode(
        token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
    )
    sub = payload.get("sub")
    if sub is None:
        raise jwt.InvalidTokenError("token missing subject")
    return int(sub)
