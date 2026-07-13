from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.insight import AIInsightOut
from app.services.insight_service import InsightService, generate_daily_insights_for

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("", response_model=list[AIInsightOut])
def list_insights(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = InsightService(db)
    if not service._has_todays_batch(current_user):
        background_tasks.add_task(generate_daily_insights_for, current_user.id)
    return service.list_active(current_user)


@router.post("/refresh", response_model=list[AIInsightOut])
def refresh_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightService(db)
    service.generate_and_store(current_user)
    return service.list_active(current_user)


@router.patch("/{insight_id}/dismiss", status_code=204)
def dismiss_insight(
    insight_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    InsightService(db).dismiss(current_user, insight_id)
