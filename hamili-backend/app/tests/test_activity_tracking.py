"""
Activity is what the admin console reads as "who is using Hamili". It is
recorded on authenticated requests, at most once per 15 minutes per user,
plus one row per local day the user was active.
"""

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.core.clock import local_today
from app.db.session import SessionLocal
from app.main import app
from app.models.activity import UserActivityDay
from app.models.user import User
from app.services.activity_service import ActivityService

client = TestClient(app)
NOON_UTC = datetime(2030, 3, 4, 4, 0, tzinfo=timezone.utc)


def _register(email: str) -> dict:
    client.post("/auth/register", json={"email": email, "password": "SecurePass123", "preferred_name": "Act"})
    token = client.post("/auth/login", json={"email": email, "password": "SecurePass123"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def test_authenticated_request_sets_last_active_and_activity_day():
    headers = _register("act_request@example.com")

    assert client.get("/auth/me", headers=headers).status_code == 200

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == "act_request@example.com").one()
        days = db.query(UserActivityDay).filter(UserActivityDay.user_id == user.id).all()
        assert user.last_active_at is not None
        assert [d.day for d in days] == [local_today()]
    finally:
        db.close()


def test_touch_is_throttled_to_15_minutes():
    _register("act_throttle@example.com")
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == "act_throttle@example.com").one()
        service = ActivityService(db)

        service.touch(user, now=NOON_UTC)
        service.touch(user, now=NOON_UTC + timedelta(minutes=5))
        assert _as_utc(user.last_active_at) == NOON_UTC

        service.touch(user, now=NOON_UTC + timedelta(minutes=16))
        assert _as_utc(user.last_active_at) == NOON_UTC + timedelta(minutes=16)
    finally:
        db.close()


def test_activity_day_is_recorded_once_per_day():
    _register("act_once@example.com")
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == "act_once@example.com").one()
        service = ActivityService(db)
        for minutes in (0, 20, 40):
            service.touch(user, now=NOON_UTC + timedelta(minutes=minutes))

        rows = db.query(UserActivityDay).filter(UserActivityDay.user_id == user.id).all()
        assert len(rows) == 1
    finally:
        db.close()
