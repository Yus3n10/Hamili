"""
The app's notion of "today". Render runs in UTC, but Hamili's users live in
one timezone (APP_TIMEZONE, Asia/Manila by default), so anything that picks
a default date, month or due day must use the local calendar day. Between
00:00 and 08:00 in Manila the UTC date is still yesterday.
"""

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from app.core.config import get_settings


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _zone() -> ZoneInfo:
    return ZoneInfo(get_settings().app_timezone)


def local_today() -> date:
    return _utc_now().astimezone(_zone()).date()


def local_day_bounds_utc(day: date) -> tuple[datetime, datetime]:
    """[start, end) of a local calendar day as UTC instants, for filtering
    timestamp columns stored in UTC."""
    start = datetime.combine(day, time.min, tzinfo=_zone())
    end = start + timedelta(days=1)
    return start.astimezone(timezone.utc), end.astimezone(timezone.utc)
