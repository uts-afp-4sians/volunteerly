from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user
from src.auth.schema import AuthResponse, LoginRequest, RegisterRequest
from src.auth.security import create_access_token
from src.auth.service import (
    EmailAlreadyRegistered,
    InvalidCredentials,
    authenticate_user,
    register_user,
)
from src.lib.database import get_db
from src.users.model import User
from src.users.schema import UserRead

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED
)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> AuthResponse:
    try:
        user = register_user(db, payload)
    except EmailAlreadyRegistered:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        ) from None
    return AuthResponse(
        token=create_access_token(user.user_id),
        user=UserRead.model_validate(user),
    )


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    try:
        user = authenticate_user(db, payload.email, payload.password)
    except InvalidCredentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        ) from None
    return AuthResponse(
        token=create_access_token(user.user_id),
        user=UserRead.model_validate(user),
    )


@router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)) -> User:
    return current_user
