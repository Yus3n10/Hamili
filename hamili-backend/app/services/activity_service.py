from datetime import date, datetime, timedelta, timezone

from sqlalchemy.dialects import postgresql, sqlite
from sqlalchemy.orm import Session

from app.core.clock import local_date
from app.models.activity import AIUsageEvent, UserActivityDay
from app.models.user import User
from app.services.ai.base_provider import AIUsage

TOUCH_INTERVAL = timedelta(minutes=15)


def _as_utc(value: datetime) -> datetime:
    # SQLite hands timestamps back without a zone; they are stored as UTC.
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


class ActivityService:
    def __init__(self, db: Session):
        self.db = db

    def touch(self, user: User, now: datetime | None = None) -> None:
        """Mark the user active, at most once per TOUCH_INTERVAL, so normal
        requests pay for one extra write per user per 15 minutes."""
        now = now or datetime.now(timezone.utc)
        if user.last_active_at is not None and now - _as_utc(user.last_active_at) < TOUCH_INTERVAL:
            return

        user.last_active_at = now
        self._record_day(user.id, local_date(now))
        self.db.commit()

    def _record_day(self, user_id: int, day: date) -> None:
        # The dashboard fires several requests at once, so the first ones of a
        # day race to insert the same row; let the database drop duplicates.
        insert = postgresql.insert if self.db.get_bind().dialect.name == "postgresql" else sqlite.insert
        self.db.execute(
            insert(UserActivityDay)
            .values(user_id=user_id, day=day)
            .on_conflict_do_nothing(index_elements=["user_id", "day"])
        )

    def record_ai_usage(self, user_id: int, kind: str, usage: AIUsage | None) -> None:
        """One row per AI call; kind is "chat" or "insight"."""
        self.db.add(
            AIUsageEvent(
                user_id=user_id,
                kind=kind,
                model=usage.model if usage else None,
                prompt_tokens=usage.prompt_tokens if usage else None,
                output_tokens=usage.output_tokens if usage else None,
                total_tokens=usage.total_tokens if usage else None,
            )
        )
        self.db.commit()
