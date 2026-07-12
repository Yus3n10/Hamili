from sqlalchemy.orm import Session

from app.models.goal import SavingsGoal


class GoalRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: int) -> list[SavingsGoal]:
        return self.db.query(SavingsGoal).filter(SavingsGoal.user_id == user_id).order_by(SavingsGoal.created_at.desc()).all()

    def get(self, goal_id: int, user_id: int) -> SavingsGoal | None:
        return self.db.query(SavingsGoal).filter(SavingsGoal.id == goal_id, SavingsGoal.user_id == user_id).first()

    def create(self, goal: SavingsGoal) -> SavingsGoal:
        self.db.add(goal)
        self.db.commit()
        self.db.refresh(goal)
        return goal

    def save(self, goal: SavingsGoal) -> SavingsGoal:
        self.db.commit()
        self.db.refresh(goal)
        return goal

    def delete(self, goal: SavingsGoal) -> None:
        self.db.delete(goal)
        self.db.commit()
