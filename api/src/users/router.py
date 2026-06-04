from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from src.lib.database import get_db
from src.users.model import User, UserInterest, UserProfile
from src.users.schema import UserInterestRead, UserProfileRead, UserRead

router = APIRouter(tags=["users"])


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
