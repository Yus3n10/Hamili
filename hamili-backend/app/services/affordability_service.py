"""
Answers "can I afford this?" from the user's real numbers. Hami's yes or no
comes from here, never from the model's wording, so the reply and the
gesture always agree with the data.

Available money is the all-time balance (income minus expenses), the same
figure the dashboard shows as "Total balance". When the purchase names a
category with a budget this month, the budget's remaining amount applies too.
"""

from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.core.clock import local_today
from app.models.category import Category
from app.models.user import User
from app.repositories.analytics_repository import AnalyticsRepository
from app.repositories.budget_repository import BudgetRepository
from app.services.budget_rules import ALERT_HIGH, ALERT_OVER, budget_alert_level

ANSWER_AFFIRMATIVE = "affirmative"
ANSWER_NEGATIVE = "negative"
ANSWER_WARNING = "warning"

_CURRENCY_SYMBOLS = {"PHP": "₱", "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥"}


def format_money(amount: float, currency: str | None) -> str:
    code = (currency or "PHP").upper()
    symbol = _CURRENCY_SYMBOLS.get(code, f"{code} ")
    text = f"{abs(amount):,.2f}".removesuffix(".00")
    return f"-{symbol}{text}" if amount < 0 else f"{symbol}{text}"


@dataclass(frozen=True)
class AffordabilityResult:
    answer: str
    reply: str


class AffordabilityService:
    def __init__(self, db: Session):
        self.db = db

    def check(self, user: User, amount: float, category_name: str | None = None) -> AffordabilityResult:
        if amount <= 0:
            raise ValueError("amount must be positive")
        money = lambda value: format_money(value, user.preferred_currency)  # noqa: E731

        totals = AnalyticsRepository(self.db).totals(user.id, None, None)
        balance = totals["income"] - totals["expense"]
        if balance <= 0:
            return AffordabilityResult(
                ANSWER_NEGATIVE,
                f"No, you don't have money available right now. Your balance is {money(balance)}.",
            )
        if amount > balance:
            return AffordabilityResult(
                ANSWER_NEGATIVE,
                f"No, because you only have {money(balance)} available.",
            )

        budget_note = ""
        category = self._find_expense_category(category_name)
        if category is not None:
            today = local_today()
            repo = BudgetRepository(self.db)
            budget = repo.get_by_period_category(user.id, category.id, today.month, today.year)
            if budget is not None:
                limit = float(budget.limit_amount)
                spent = repo.spent_amount(user.id, category.id, today.month, today.year)
                remaining = limit - spent
                if remaining <= 0:
                    return AffordabilityResult(
                        ANSWER_NEGATIVE,
                        f"No, your {category.name} budget is already used up this month.",
                    )
                after_pct = (spent + amount) / limit * 100
                level = budget_alert_level(after_pct)
                if level == ALERT_OVER:
                    return AffordabilityResult(
                        ANSWER_NEGATIVE,
                        f"No, that would put your {category.name} budget over. "
                        f"You have {money(remaining)} left in it this month.",
                    )
                if level == ALERT_HIGH:
                    return AffordabilityResult(
                        ANSWER_WARNING,
                        f"You can, but it would use {round(after_pct)}% of your {category.name} budget this month.",
                    )
                budget_note = f" You'd still have {money(remaining - amount)} left in your {category.name} budget."

        return AffordabilityResult(
            ANSWER_AFFIRMATIVE,
            f"Yes, you have {money(balance)} available, so {money(amount)} fits.{budget_note}",
        )

    def _find_expense_category(self, name: str | None) -> Category | None:
        name_l = (name or "").lower().strip()
        if not name_l:
            return None
        cats = [c for c in self.db.query(Category).all() if c.type == "expense"]
        for c in cats:
            if c.name.lower() == name_l:
                return c
        for c in cats:
            if name_l in c.name.lower() or c.name.lower() in name_l:
                return c
        return None
