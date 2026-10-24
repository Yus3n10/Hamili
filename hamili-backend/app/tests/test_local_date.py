"""
"Today" must follow the app's local timezone (Asia/Manila), not the server's
UTC clock. These run at 01:30 on 1 Jan 2031 in Manila, which is still
31 Dec 2030 in UTC, so any code reading the UTC date lands in the wrong day,
month and year.
"""

from datetime import date, datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.core import clock
from app.db.session import SessionLocal
from app.main import app
from app.models.ai import AIInsight
from app.models.budget import Budget
from app.models.transaction import Transaction
from app.models.user import User
from app.services.agent_service import AgentService
from app.services.insight_service import InsightService

client = TestClient(app)

MANILA_NEW_YEAR_0130 = datetime(2030, 12, 31, 17, 30, tzinfo=timezone.utc)
LOCAL_TODAY = date(2031, 1, 1)


@pytest.fixture
def frozen_clock(monkeypatch):
    monkeypatch.setattr(clock, "_utc_now", lambda: MANILA_NEW_YEAR_0130)


def _auth_headers(email: str) -> dict:
    password = "SecurePass123"
    client.post("/auth/register", json={"email": email, "password": password, "preferred_name": "Clock Test"})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _category_id(headers: dict, name: str) -> int:
    return next(c["id"] for c in client.get("/categories", headers=headers).json() if c["name"] == name)


def test_local_today_follows_manila_not_utc(frozen_clock):
    assert clock.local_today() == LOCAL_TODAY


def test_local_today_before_manila_midnight(monkeypatch):
    monkeypatch.setattr(clock, "_utc_now", lambda: datetime(2030, 12, 31, 15, 59, tzinfo=timezone.utc))
    assert clock.local_today() == date(2030, 12, 31)


def test_budgets_default_to_the_local_month(frozen_clock):
    headers = _auth_headers("clock_budget@example.com")
    food = _category_id(headers, "Food")
    client.post("/budgets", headers=headers, json={"category_id": food, "month": 1, "year": 2031, "limit_amount": 3000})

    listed = client.get("/budgets", headers=headers).json()

    assert [b["category_id"] for b in listed] == [food]


def test_category_breakdown_defaults_to_the_local_month(frozen_clock):
    headers = _auth_headers("clock_analytics@example.com")
    food = _category_id(headers, "Food")
    client.post(
        "/transactions",
        headers=headers,
        json={"category_id": food, "amount": 250, "type": "expense", "transaction_date": "2031-01-01"},
    )

    breakdown = client.get("/analytics/by-category", headers=headers).json()

    assert breakdown == [{"category_id": food, "total": 250.0}]


def test_recurring_item_due_on_the_local_day_is_promoted(frozen_clock):
    headers = _auth_headers("clock_recurring@example.com")
    salary = _category_id(headers, "Salary")
    client.post(
        "/recurring",
        headers=headers,
        json={
            "type": "income",
            "name": "New Year Salary",
            "amount": 1000,
            "category_id": salary,
            "frequency": "monthly",
            "next_due_date": "2031-01-01",
        },
    )

    run = client.post("/recurring/run-due", headers=headers).json()

    assert run["promoted"] == 1


def _user(email: str) -> User:
    _auth_headers(email)
    db = SessionLocal()
    user = db.query(User).filter(User.email == email).first()
    db.close()
    return user


def test_hami_sets_budgets_for_the_local_month(frozen_clock):
    user = _user("clock_agent_budget@example.com")
    db = SessionLocal()
    try:
        AgentService(db)._execute(db.merge(user), "set_budget", {"category": "Food", "limit_amount": 500})
        budget = db.query(Budget).filter(Budget.user_id == user.id).one()
        assert (budget.year, budget.month) == (2031, 1)
    finally:
        db.close()


def test_hami_dates_transactions_on_the_local_day(frozen_clock):
    user = _user("clock_agent_txn@example.com")
    db = SessionLocal()
    try:
        AgentService(db)._execute(db.merge(user), "add_transaction", {"type": "expense", "amount": 99, "category": "Food"})
        txn = db.query(Transaction).filter(Transaction.user_id == user.id).one()
        assert txn.transaction_date == LOCAL_TODAY
    finally:
        db.close()


def _store_insight(user_id: int, created_at_utc: datetime) -> None:
    db = SessionLocal()
    try:
        db.add(AIInsight(user_id=user_id, insight_type="general", message="x", is_read=True, created_at=created_at_utc))
        db.commit()
    finally:
        db.close()


def test_insight_from_after_local_midnight_counts_as_todays_batch(frozen_clock):
    user = _user("clock_insight_today@example.com")
    _store_insight(user.id, datetime(2030, 12, 31, 16, 30, tzinfo=timezone.utc))

    db = SessionLocal()
    try:
        assert InsightService(db)._has_todays_batch(db.merge(user)) is True
    finally:
        db.close()


def test_insight_from_the_previous_local_day_does_not_count(frozen_clock):
    user = _user("clock_insight_yesterday@example.com")
    _store_insight(user.id, datetime(2030, 12, 31, 15, 30, tzinfo=timezone.utc))

    db = SessionLocal()
    try:
        assert InsightService(db)._has_todays_batch(db.merge(user)) is False
    finally:
        db.close()
