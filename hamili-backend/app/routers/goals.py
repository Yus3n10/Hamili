from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.goal import GoalContribution, SavingsGoalCreate, SavingsGoalOut, SavingsGoalUpdate
from app.services.goal_service import GoalService

router = APIRouter(prefix="/goals", tags=["goals"])


@router.get("", response_model=list[SavingsGoalOut])
def list_goals(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return GoalService(db).list(current_user)


@router.post("", response_model=SavingsGoalOut, status_code=201)
def create_goal(
    payload: SavingsGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return GoalService(db).create(current_user, payload)


@router.patch("/{goal_id}", response_model=SavingsGoalOut)
def update_goal(
    goal_id: int,
    payload: SavingsGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return GoalService(db).update(current_user, goal_id, payload)


@router.post("/{goal_id}/contribute", response_model=SavingsGoalOut)
def contribute_to_goal(
    goal_id: int,
    payload: GoalContribution,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return GoalService(db).contribute(current_user, goal_id, payload)


@router.delete("/{goal_id}", status_code=204)
def delete_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    GoalService(db).delete(current_user, goal_id)
