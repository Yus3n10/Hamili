from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.core.rate_limit import (
    REGISTER_LIMIT,
    ensure_login_allowed,
    limiter,
    record_login_failure,
    reset_login_failures,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import TokenPair, TokenRefresh, UserLogin, UserOut, UserRegister, UserUpdate
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=201)
@limiter.limit(REGISTER_LIMIT)
def register(request: Request, payload: UserRegister, db: Session = Depends(get_db)):
    return AuthService(db).register(payload)


@router.post("/login", response_model=TokenPair)
def login(request: Request, payload: UserLogin, db: Session = Depends(get_db)):
    ip = get_remote_address(request)
    ensure_login_allowed(ip)
    try:
        result = AuthService(db).login(payload)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            record_login_failure(ip)
        raise
    reset_login_failures(ip)
    return result


@router.post("/refresh", response_model=TokenPair)
def refresh(payload: TokenRefresh, db: Session = Depends(get_db)):
    return AuthService(db).refresh(payload.refresh_token)


@router.get("/me", response_model=UserOut)
def read_current_user(current_user: User = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=UserOut)
def update_current_user(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AuthService(db).update_profile(current_user, payload)
