from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.auth.deps import get_current_user
from src.lib.database import get_db
from src.users.model import User, UserInterest, UserProfile
from src.users.schema import (
    UserInterestRead,
    UserProfileRead,
    UserProfileUpdate,
    UserRead,
)
from src.users.service import (
    ProfileNotFound,
    UnknownKeyword,
    get_profile,
    read_profile_with_interests,
    update_profile,
)

router = APIRouter(tags=["users"])


# MARK: - Current user ("/me")


@router.get("/me/profile", response_model=UserProfileRead)
def get_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserProfileRead:
    try:
        profile = get_profile(db, current_user.user_id)
    except ProfileNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found"
        ) from None
    return read_profile_with_interests(db, profile)


@router.patch("/me/profile", response_model=UserProfileRead)
def update_my_profile(
    payload: UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserProfileRead:
    try:
        profile = update_profile(db, current_user.user_id, payload)
    except ProfileNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found"
        ) from None
    except UnknownKeyword as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        ) from None
    return read_profile_with_interests(db, profile)


# MARK: - Public reads ("/users/{user_id}")


@router.get("/users/{user_id}", response_model=UserRead)
def get_user(user_id: int, db: Session = Depends(get_db)) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    return user


@router.get("/users/{user_id}/profile", response_model=UserProfileRead)
def get_user_profile(user_id: int, db: Session = Depends(get_db)) -> UserProfile:
    profile = db.get(UserProfile, user_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found"
        )
    return profile


@router.get("/users/{user_id}/interests", response_model=list[UserInterestRead])
def list_user_interests(
    user_id: int, db: Session = Depends(get_db)
) -> list[UserInterest]:
    result = db.execute(
        select(UserInterest)
        .where(UserInterest.user_id == user_id)
        .order_by(UserInterest.keyword_id)
    )
    return list(result.scalars().all())
