from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.core.rate_limit import LOGIN_LIMIT, limiter
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import TokenPair, UserLogin, UserOut, UserRegister, UserUpdate
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=201)
@limiter.limit(LOGIN_LIMIT)
def register(request: Request, payload: UserRegister, db: Session = Depends(get_db)):
    return AuthService(db).register(payload)


@router.post("/login", response_model=TokenPair)
@limiter.limit(LOGIN_LIMIT)
def login(request: Request, payload: UserLogin, db: Session = Depends(get_db)):
    return AuthService(db).login(payload)


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
