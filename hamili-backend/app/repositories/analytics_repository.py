from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.transaction import Transaction


class AnalyticsRepository:
    def __init__(self, db: Session):
        self.db = db

    def totals(self, user_id: int, month: int | None, year: int | None) -> dict[str, float]:
        """Sum of income and of expense, optionally scoped to a month/year."""
        q = self.db.query(
            Transaction.type,
            func.coalesce(func.sum(Transaction.amount), 0),
        ).filter(Transaction.user_id == user_id)
        if month is not None and year is not None:
            q = q.filter(
                extract("month", Transaction.transaction_date) == month,
                extract("year", Transaction.transaction_date) == year,
            )
        rows = q.group_by(Transaction.type).all()
        out = {"income": 0.0, "expense": 0.0}
        for t_type, total in rows:
            out[t_type] = float(total or 0)
        return out

    def by_category(self, user_id: int, t_type: str, month: int, year: int) -> list[tuple[int, float]]:
        rows = (
            self.db.query(Transaction.category_id, func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.user_id == user_id,
                Transaction.type == t_type,
                extract("month", Transaction.transaction_date) == month,
                extract("year", Transaction.transaction_date) == year,
            )
            .group_by(Transaction.category_id)
            .all()
        )
        result = [(cat_id, float(total or 0)) for cat_id, total in rows]
        result.sort(key=lambda r: r[1], reverse=True)
        return result

    def income_expense_by_month(
        self, user_id: int, months: list[tuple[int, int]]
    ) -> dict[tuple[int, int], dict[str, float]]:
        """Income and expense totals grouped by (year, month) over the given
        window. Returns only months that have data; the service zero-fills."""
        if not months:
            return {}
        years = {y for y, _ in months}
        rows = (
            self.db.query(
                extract("year", Transaction.transaction_date),
                extract("month", Transaction.transaction_date),
                Transaction.type,
                func.coalesce(func.sum(Transaction.amount), 0),
            )
            .filter(
                Transaction.user_id == user_id,
                extract("year", Transaction.transaction_date).in_(years),
            )
            .group_by(
                extract("year", Transaction.transaction_date),
                extract("month", Transaction.transaction_date),
                Transaction.type,
            )
            .all()
        )
        wanted = set(months)
        out: dict[tuple[int, int], dict[str, float]] = {}
        for year, month, t_type, total in rows:
            key = (int(year), int(month))
            if key not in wanted:
                continue
            out.setdefault(key, {"income": 0.0, "expense": 0.0})
            out[key][t_type] = float(total or 0)
        return out
