from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import TokenPair, UserLogin, UserRegister, UserUpdate


class AuthService:
    def __init__(self, db: Session):
        self.repo = UserRepository(db)

    def register(self, payload: UserRegister) -> User:
        if self.repo.get_by_email(payload.email):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Email already registered")

        user = User(
            email=payload.email,
            password_hash=hash_password(payload.password),
            preferred_name=payload.preferred_name,
        )
        return self.repo.create(user)

    def update_profile(self, user: User, payload: UserUpdate) -> User:
        """Partial profile update — used by onboarding and the profile
        editor. Only fields the client actually sends are changed."""
        return self.repo.update(user, **payload.model_dump(exclude_unset=True))

    def login(self, payload: UserLogin) -> TokenPair:
        user = self.repo.get_by_email(payload.email)
        if not user or not verify_password(payload.password, user.password_hash):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Incorrect email or password")

        return TokenPair(
            access_token=create_access_token(str(user.id)),
            refresh_token=create_refresh_token(str(user.id)),
        )

    def refresh(self, refresh_token: str) -> TokenPair:
        payload = decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired refresh token")

        user = self.repo.get_by_id(int(payload["sub"]))
        if not user:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")

        return TokenPair(
            access_token=create_access_token(str(user.id)),
            refresh_token=create_refresh_token(str(user.id)),
        )
