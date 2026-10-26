from datetime import date, datetime

from sqlalchemy import func, or_, select, true
from sqlalchemy.orm import Session

from app.models.activity import AdminAccessLog, AIUsageEvent, UserActivityDay
from app.models.budget import Budget
from app.models.goal import SavingsGoal
from app.models.transaction import Transaction
from app.models.user import User

SORTS = ("last_active", "joined", "hami_tokens", "name")


def _escape_like(text: str) -> str:
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


class AdminRepository:
    """Read-only queries for the admin console. Every query that touches a
    tester table returns counts or timestamps, never row contents."""

    def __init__(self, db: Session, admin_ids: set[int]):
        self.db = db
        self.admin_ids = admin_ids

    def _not_admin(self, column):
        return ~column.in_(self.admin_ids) if self.admin_ids else true()

    def testers_total(self) -> int:
        return self.db.query(func.count(User.id)).filter(self._not_admin(User.id)).scalar() or 0

    def active_since(self, first_day: date) -> int:
        return (
            self.db.query(func.count(func.distinct(UserActivityDay.user_id)))
            .filter(UserActivityDay.day >= first_day, self._not_admin(UserActivityDay.user_id))
            .scalar()
            or 0
        )

    def joined_since(self, since: datetime) -> int:
        return (
            self.db.query(func.count(User.id)).filter(User.created_at >= since, self._not_admin(User.id)).scalar() or 0
        )

    def chat_messages_since(self, since: datetime) -> int:
        return (
            self.db.query(func.count(AIUsageEvent.id))
            .filter(AIUsageEvent.kind == "chat", AIUsageEvent.created_at >= since, self._not_admin(AIUsageEvent.user_id))
            .scalar()
            or 0
        )

    def active_by_day(self, first_day: date) -> dict[date, int]:
        rows = (
            self.db.query(UserActivityDay.day, func.count(UserActivityDay.user_id))
            .filter(UserActivityDay.day >= first_day, self._not_admin(UserActivityDay.user_id))
            .group_by(UserActivityDay.day)
            .all()
        )
        return {day: count for day, count in rows}

    def token_events_since(self, since: datetime) -> list[tuple[datetime, int]]:
        rows = (
            self.db.query(AIUsageEvent.created_at, AIUsageEvent.total_tokens)
            .filter(AIUsageEvent.created_at >= since, self._not_admin(AIUsageEvent.user_id))
            .all()
        )
        return [(created_at, tokens or 0) for created_at, tokens in rows]

    def tracking_since(self) -> date | None:
        return self.db.query(func.min(UserActivityDay.day)).scalar()

    def testers_page(
        self, search: str, sort: str, page: int, page_size: int, days_from: date, tokens_since: datetime
    ) -> tuple[list[dict], int]:
        def count_of(column, *conditions):
            return select(func.count(column)).where(*conditions).correlate(User).scalar_subquery()

        def tokens_where(*conditions):
            return (
                select(func.coalesce(func.sum(AIUsageEvent.total_tokens), 0))
                .where(AIUsageEvent.user_id == User.id, *conditions)
                .correlate(User)
                .scalar_subquery()
            )

        columns = {
            "days_active_30d": count_of(
                UserActivityDay.id, UserActivityDay.user_id == User.id, UserActivityDay.day >= days_from
            ),
            "transactions_count": count_of(Transaction.id, Transaction.user_id == User.id),
            "budgets_count": count_of(Budget.id, Budget.user_id == User.id),
            "goals_count": count_of(SavingsGoal.id, SavingsGoal.user_id == User.id),
            "hami_messages_total": count_of(
                AIUsageEvent.id, AIUsageEvent.user_id == User.id, AIUsageEvent.kind == "chat"
            ),
            "hami_tokens_total": tokens_where(),
            "hami_tokens_7d": tokens_where(AIUsageEvent.created_at >= tokens_since),
            "hami_tokens_chat": tokens_where(AIUsageEvent.kind == "chat"),
            "hami_tokens_insight": tokens_where(AIUsageEvent.kind == "insight"),
        }

        filters = [self._not_admin(User.id)]
        if search:
            pattern = f"%{_escape_like(search)}%"
            filters.append(or_(User.preferred_name.ilike(pattern, escape="\\"), User.email.ilike(pattern, escape="\\")))

        total = self.db.query(func.count(User.id)).filter(*filters).scalar() or 0
        order = {
            "last_active": User.last_active_at.desc().nulls_last(),
            "joined": User.created_at.desc(),
            "hami_tokens": columns["hami_tokens_total"].desc(),
            "name": func.lower(User.preferred_name).asc(),
        }[sort]
        rows = (
            self.db.query(User, *(expr.label(name) for name, expr in columns.items()))
            .filter(*filters)
            .order_by(order, User.id)
            .offset((page - 1) * page_size)
            .limit(page_size)
            .all()
        )
        items = [
            {
                "id": user.id,
                "name": user.preferred_name,
                "email": user.email,
                "joined_at": user.created_at,
                "last_active_at": user.last_active_at,
                **{name: int(getattr(row, name) or 0) for name in columns},
            }
            for row in rows
            for user in [row[0]]
        ]
        return items, total

    def access_log_page(self, admin_id: int, page: int, page_size: int) -> tuple[list[AdminAccessLog], int]:
        query = self.db.query(AdminAccessLog).filter(AdminAccessLog.admin_user_id == admin_id)
        total = query.count()
        items = (
            query.order_by(AdminAccessLog.created_at.desc(), AdminAccessLog.id.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
            .all()
        )
        return items, total
