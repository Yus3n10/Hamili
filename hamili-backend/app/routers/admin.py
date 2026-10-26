from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.admin import require_admin
from app.db.session import get_db
from app.models.user import User
from app.schemas.admin import AdminAccessPage, AdminOverviewOut, AdminTesterPage
from app.services.admin_service import AdminService

# include_in_schema=False keeps the routes out of the public /docs page.
router = APIRouter(prefix="/admin", tags=["admin"], include_in_schema=False)


@router.get("/overview", response_model=AdminOverviewOut)
def overview(_: User = Depends(require_admin), db: Session = Depends(get_db)):
    return AdminService(db).overview()


@router.get("/testers", response_model=AdminTesterPage)
def testers(
    search: str = Query(default="", max_length=100),
    sort: Literal["last_active", "joined", "hami_tokens", "name"] = "last_active",
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return AdminService(db).testers(search, sort, page, page_size)


@router.get("/access-log", response_model=AdminAccessPage)
def access_log(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return AdminService(db).access_log(admin, page, page_size)
