from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.core.clock import local_date, local_day_bounds_utc, local_today
from app.core.config import get_settings
from app.models.user import User
from app.repositories.admin_repository import AdminRepository
from app.schemas.admin import (
    AdminAccessEntryOut,
    AdminAccessPage,
    AdminDayPoint,
    AdminOverviewOut,
    AdminTesterOut,
    AdminTesterPage,
)

TREND_DAYS = 30


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


class AdminService:
    def __init__(self, db: Session):
        self.repo = AdminRepository(db, get_settings().admin_id_set)

    def _start_of(self, day: date) -> datetime:
        return local_day_bounds_utc(day)[0]

    def overview(self) -> AdminOverviewOut:
        today = local_today()
        week_start = today - timedelta(days=6)
        trend_start = today - timedelta(days=TREND_DAYS - 1)

        tokens_by_day: dict[date, int] = {}
        for created_at, tokens in self.repo.token_events_since(self._start_of(trend_start)):
            day = local_date(_as_utc(created_at))
            tokens_by_day[day] = tokens_by_day.get(day, 0) + tokens
        active_by_day = self.repo.active_by_day(trend_start)
        daily = [
            AdminDayPoint(day=day, active_testers=active_by_day.get(day, 0), hami_tokens=tokens_by_day.get(day, 0))
            for day in (trend_start + timedelta(days=i) for i in range(TREND_DAYS))
        ]

        return AdminOverviewOut(
            testers_total=self.repo.testers_total(),
            active_today=self.repo.active_since(today),
            active_7d=self.repo.active_since(week_start),
            active_30d=self.repo.active_since(trend_start),
            new_7d=self.repo.joined_since(self._start_of(week_start)),
            hami_messages_7d=self.repo.chat_messages_since(self._start_of(week_start)),
            hami_tokens_7d=sum(p.hami_tokens for p in daily if p.day >= week_start),
            daily=daily,
            tracking_since=self.repo.tracking_since(),
        )

    def testers(self, search: str, sort: str, page: int, page_size: int) -> AdminTesterPage:
        today = local_today()
        items, total = self.repo.testers_page(
            search=search.strip(),
            sort=sort,
            page=page,
            page_size=page_size,
            days_from=today - timedelta(days=TREND_DAYS - 1),
            tokens_since=self._start_of(today - timedelta(days=6)),
        )
        return AdminTesterPage(
            items=[AdminTesterOut(**item) for item in items], total=total, page=page, page_size=page_size
        )

    def access_log(self, admin: User, page: int, page_size: int) -> AdminAccessPage:
        items, total = self.repo.access_log_page(admin.id, page, page_size)
        return AdminAccessPage(
            items=[AdminAccessEntryOut(path=i.path, created_at=i.created_at) for i in items],
            total=total,
            page=page,
            page_size=page_size,
        )
