from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.user import User
from app.repositories.budget_repository import BudgetRepository
from app.schemas.budget import BudgetCreate, BudgetOut, BudgetUpdate


class BudgetService:
    def __init__(self, db: Session):
        self.repo = BudgetRepository(db)

    def list(self, user: User, month: int, year: int) -> list[BudgetOut]:
        budgets = self.repo.list_for_period(user.id, month, year)
        return [self._to_out(user, b) for b in budgets]

    def create_or_update(self, user: User, payload: BudgetCreate) -> BudgetOut:
        existing = self.repo.get_by_period_category(user.id, payload.category_id, payload.month, payload.year)
        if existing:
            budget = self.repo.update(existing, payload.limit_amount)
        else:
            budget = self.repo.create(
                Budget(
                    user_id=user.id,
                    category_id=payload.category_id,
                    month=payload.month,
                    year=payload.year,
                    limit_amount=payload.limit_amount,
                )
            )
        return self._to_out(user, budget)

    def update(self, user: User, budget_id: int, payload: BudgetUpdate) -> BudgetOut:
        budget = self._get_owned(user, budget_id)
        budget = self.repo.update(budget, payload.limit_amount)
        return self._to_out(user, budget)

    def delete(self, user: User, budget_id: int) -> None:
        budget = self._get_owned(user, budget_id)
        self.repo.delete(budget)

    def _get_owned(self, user: User, budget_id: int) -> Budget:
        budget = self.repo.get(budget_id, user.id)
        if not budget:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Budget not found")
        return budget

    def _to_out(self, user: User, budget: Budget) -> BudgetOut:
        spent = self.repo.spent_amount(user.id, budget.category_id, budget.month, budget.year)
        limit = float(budget.limit_amount)
        remaining = limit - spent
        percentage = round((spent / limit) * 100, 1) if limit > 0 else 0.0

        return BudgetOut(
            id=budget.id,
            category_id=budget.category_id,
            month=budget.month,
            year=budget.year,
            limit_amount=limit,
            spent_amount=spent,
            remaining_amount=remaining,
            percentage_used=percentage,
        )
