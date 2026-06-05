from pydantic import BaseModel, EmailStr, Field

from src.users.schema import UserRead


class LoginRequest(BaseModel):
    """Wire shape matching iOS `LoginRequest`."""

    email: EmailStr
    # max_length 72 mirrors bcrypt's byte limit (see auth.security).
    password: str = Field(min_length=8, max_length=72)


class RegisterRequest(BaseModel):
    """Sign-up payload: creates a `User` plus its `UserProfile`."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    first_name: str = Field(min_length=1, max_length=255)
    last_name: str = Field(min_length=1, max_length=255)


class AuthResponse(BaseModel):
    """Wire shape matching iOS `AuthResponse` ({ token, user })."""

    token: str
    user: UserRead
