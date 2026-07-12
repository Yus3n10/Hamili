from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.transaction import Transaction


class BudgetRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_period(self, user_id: int, month: int, year: int) -> list[Budget]:
        return (
            self.db.query(Budget)
            .filter(Budget.user_id == user_id, Budget.month == month, Budget.year == year)
            .all()
        )

    def get(self, budget_id: int, user_id: int) -> Budget | None:
        return self.db.query(Budget).filter(Budget.id == budget_id, Budget.user_id == user_id).first()

    def get_by_period_category(self, user_id: int, category_id: int, month: int, year: int) -> Budget | None:
        return (
            self.db.query(Budget)
            .filter(
                Budget.user_id == user_id,
                Budget.category_id == category_id,
                Budget.month == month,
                Budget.year == year,
            )
            .first()
        )

    def create(self, budget: Budget) -> Budget:
        self.db.add(budget)
        self.db.commit()
        self.db.refresh(budget)
        return budget

    def update(self, budget: Budget, limit_amount: float) -> Budget:
        budget.limit_amount = limit_amount
        self.db.commit()
        self.db.refresh(budget)
        return budget

    def delete(self, budget: Budget) -> None:
        self.db.delete(budget)
        self.db.commit()

    def spent_amount(self, user_id: int, category_id: int, month: int, year: int) -> float:
        """Sums actual expense transactions for this category/month/year —
        this is what makes a budget 'live' instead of a static number."""
        total = (
            self.db.query(func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.user_id == user_id,
                Transaction.category_id == category_id,
                Transaction.type == "expense",
                extract("month", Transaction.transaction_date) == month,
                extract("year", Transaction.transaction_date) == year,
            )
            .scalar()
        )
        return float(total or 0)
