"""
Admin console responses. Field lists are deliberate: counts and timestamps
only. Adding an amount, note, or chat field here breaks the privacy promise
testers are shown in the app.
"""

from datetime import date, datetime

from pydantic import BaseModel


class AdminDayPoint(BaseModel):
    day: date
    active_testers: int
    hami_tokens: int


class AdminOverviewOut(BaseModel):
    testers_total: int
    active_today: int
    active_7d: int
    active_30d: int
    new_7d: int
    hami_messages_7d: int
    hami_tokens_7d: int
    daily: list[AdminDayPoint]
    tracking_since: date | None


class AdminTesterOut(BaseModel):
    id: int
    name: str
    email: str
    joined_at: datetime
    last_active_at: datetime | None
    days_active_30d: int
    transactions_count: int
    budgets_count: int
    goals_count: int
    hami_messages_total: int
    hami_tokens_total: int
    hami_tokens_7d: int
    hami_tokens_chat: int
    hami_tokens_insight: int


class AdminTesterPage(BaseModel):
    items: list[AdminTesterOut]
    total: int
    page: int
    page_size: int


class AdminAccessEntryOut(BaseModel):
    path: str
    created_at: datetime


class AdminAccessPage(BaseModel):
    items: list[AdminAccessEntryOut]
    total: int
    page: int
    page_size: int
