from datetime import date, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.goal import SavingsGoal
from app.models.user import User
from app.repositories.goal_repository import GoalRepository
from app.schemas.goal import GoalContribution, SavingsGoalCreate, SavingsGoalOut, SavingsGoalUpdate


class GoalService:
    def __init__(self, db: Session):
        self.repo = GoalRepository(db)

    def list(self, user: User) -> list[SavingsGoalOut]:
        return [self._to_out(g) for g in self.repo.list_for_user(user.id)]

    def create(self, user: User, payload: SavingsGoalCreate) -> SavingsGoalOut:
        goal = SavingsGoal(
            user_id=user.id,
            title=payload.title,
            target_amount=payload.target_amount,
            target_date=payload.target_date,
            current_amount=0,
            status="in_progress",
        )
        goal = self.repo.create(goal)
        return self._to_out(goal)

    def update(self, user: User, goal_id: int, payload: SavingsGoalUpdate) -> SavingsGoalOut:
        goal = self._get_owned(user, goal_id)
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(goal, field, value)
        goal = self.repo.save(goal)
        return self._to_out(goal)

    def contribute(self, user: User, goal_id: int, payload: GoalContribution) -> SavingsGoalOut:
        """Adds to a goal's current_amount and flips status to 'completed'
        the moment the target is reached — this is what the frontend uses
        to trigger the completion celebration."""
        goal = self._get_owned(user, goal_id)
        goal.current_amount = float(goal.current_amount) + payload.amount
        if goal.current_amount >= goal.target_amount and goal.status != "completed":
            goal.status = "completed"
        goal = self.repo.save(goal)
        return self._to_out(goal)

    def delete(self, user: User, goal_id: int) -> None:
        goal = self._get_owned(user, goal_id)
        self.repo.delete(goal)

    def _get_owned(self, user: User, goal_id: int) -> SavingsGoal:
        goal = self.repo.get(goal_id, user.id)
        if not goal:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Savings goal not found")
        return goal

    def _to_out(self, goal: SavingsGoal) -> SavingsGoalOut:
        target = float(goal.target_amount)
        current = float(goal.current_amount)
        remaining = max(target - current, 0)
        percentage = round(min(current / target, 1.0) * 100, 1) if target > 0 else 0.0

        return SavingsGoalOut(
            id=goal.id,
            title=goal.title,
            target_amount=target,
            current_amount=current,
            remaining_amount=remaining,
            progress_percentage=percentage,
            target_date=goal.target_date,
            estimated_completion_date=self._estimate_completion(goal),
            status=goal.status,
        )

    def _estimate_completion(self, goal: SavingsGoal) -> date | None:
        """Naive linear projection: average monthly contribution so far,
        extrapolated forward. Returns None when there's not enough
        history to project from (no progress yet, or goal just created).
        Milestone 6+ could replace this with something that also factors
        in the user's recurring income once that data is reliably tied
        to specific goals."""
        if goal.status == "completed" or goal.current_amount <= 0:
            return None

        months_elapsed = max((date.today() - goal.created_at.date()).days / 30.44, 1 / 30.44)
        monthly_rate = float(goal.current_amount) / months_elapsed
        if monthly_rate <= 0:
            return None

        remaining = float(goal.target_amount) - float(goal.current_amount)
        months_needed = remaining / monthly_rate
        return date.today() + timedelta(days=round(months_needed * 30.44))
