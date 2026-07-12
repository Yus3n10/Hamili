from datetime import date

from sqlalchemy.orm import Session

from app.models.user import User
from app.repositories.analytics_repository import AnalyticsRepository
from app.schemas.analytics import AnalyticsSummaryOut, CategoryBreakdownOut, TrendPointOut


def month_window(end_year: int, end_month: int, months: int) -> list[tuple[int, int]]:
    """The `months` (year, month) pairs ending at (end_year, end_month)
    inclusive, oldest first."""
    result: list[tuple[int, int]] = []
    y, m = end_year, end_month
    for _ in range(months):
        result.append((y, m))
        m -= 1
        if m == 0:
            m = 12
            y -= 1
    return list(reversed(result))


class AnalyticsService:
    def __init__(self, db: Session):
        self.repo = AnalyticsRepository(db)

    def summary(self, user: User, month: int | None, year: int | None) -> AnalyticsSummaryOut:
        totals = self.repo.totals(user.id, month, year)
        income, expense = totals["income"], totals["expense"]
        return AnalyticsSummaryOut(income=income, expense=expense, net=income - expense)

    def by_category(
        self, user: User, t_type: str, month: int | None, year: int | None
    ) -> list[CategoryBreakdownOut]:
        today = date.today()
        month = month or today.month
        year = year or today.year
        rows = self.repo.by_category(user.id, t_type, month, year)
        return [CategoryBreakdownOut(category_id=cid, total=total) for cid, total in rows]

    def trend(self, user: User, month: int | None, year: int | None, months: int) -> list[TrendPointOut]:
        today = date.today()
        end_month = month or today.month
        end_year = year or today.year
        window = month_window(end_year, end_month, months)
        by_month = self.repo.income_expense_by_month(user.id, window)
        points: list[TrendPointOut] = []
        for y, m in window:
            data = by_month.get((y, m), {"income": 0.0, "expense": 0.0})
            points.append(TrendPointOut(year=y, month=m, income=data["income"], expense=data["expense"]))
        return points
