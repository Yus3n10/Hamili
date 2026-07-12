from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.analytics import AnalyticsSummaryOut, CategoryBreakdownOut, TrendPointOut
from app.services.analytics_service import AnalyticsService

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/summary", response_model=AnalyticsSummaryOut)
def summary(
    month: int | None = None,
    year: int | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AnalyticsService(db).summary(current_user, month, year)


@router.get("/by-category", response_model=list[CategoryBreakdownOut])
def by_category(
    type: str = "expense",
    month: int | None = None,
    year: int | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AnalyticsService(db).by_category(current_user, type, month, year)


@router.get("/trend", response_model=list[TrendPointOut])
def trend(
    month: int | None = None,
    year: int | None = None,
    months: int = 6,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AnalyticsService(db).trend(current_user, month, year, months)
