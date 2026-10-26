"""
Every Gemini call made for a user leaves one ai_usage_events row with the
tokens Gemini reported, so the admin console can show who uses Hami.
"""

import pytest
from fastapi.testclient import TestClient

from app.db.session import SessionLocal
from app.main import app
from app.models.activity import AIUsageEvent
from app.models.user import User
from app.services.ai.base_provider import AIProviderUnavailable, AIUsage
from app.services.insight_service import InsightService

client = TestClient(app)
USAGE = AIUsage(model="fake-model", prompt_tokens=120, output_tokens=30, total_tokens=150)


class _FakeProvider:
    def __init__(self, usage=USAGE, fail=False):
        self.usage, self.fail = usage, fail

    def interpret(self, messages, financial_context, category_names, today):
        if self.fail:
            raise AIProviderUnavailable()
        return {"action": "none", "params": {}, "reply": "Hello from fake Hami", "usage": self.usage}

    def generate_insights(self, financial_context):
        return ["You spent less on food this week."], self.usage


@pytest.fixture
def fake_provider(monkeypatch):
    def install(**kwargs):
        provider = _FakeProvider(**kwargs)
        monkeypatch.setattr("app.services.agent_service.get_ai_provider", lambda: provider)
        monkeypatch.setattr("app.services.insight_service.get_ai_provider", lambda: provider)
        return provider

    return install


def _login(email: str) -> dict:
    client.post("/auth/register", json={"email": email, "password": "SecurePass123", "preferred_name": "Usage"})
    token = client.post("/auth/login", json={"email": email, "password": "SecurePass123"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _events(email: str) -> list[AIUsageEvent]:
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        return db.query(AIUsageEvent).filter(AIUsageEvent.user_id == user.id).all()
    finally:
        db.close()


def test_chat_records_usage_row(fake_provider):
    fake_provider()
    headers = _login("usage_chat@example.com")

    reply = client.post("/chat/message", headers=headers, json={"content": "hi"}).json()

    [event] = _events("usage_chat@example.com")
    assert reply["reply"] == "Hello from fake Hami"
    assert (event.kind, event.model, event.prompt_tokens, event.output_tokens, event.total_tokens) == (
        "chat", "fake-model", 120, 30, 150,
    )


def test_missing_usage_metadata_records_null_tokens(fake_provider):
    fake_provider(usage=None)
    headers = _login("usage_none@example.com")

    reply = client.post("/chat/message", headers=headers, json={"content": "hi"}).json()

    [event] = _events("usage_none@example.com")
    assert reply["reply"] == "Hello from fake Hami"
    assert (event.kind, event.total_tokens) == ("chat", None)


def test_insight_generation_records_usage_row(fake_provider):
    fake_provider()
    _login("usage_insight@example.com")

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == "usage_insight@example.com").one()
        InsightService(db).generate_and_store(user)
    finally:
        db.close()

    [event] = _events("usage_insight@example.com")
    assert (event.kind, event.total_tokens) == ("insight", 150)


def test_provider_quota_error_records_nothing(fake_provider):
    fake_provider(fail=True)
    headers = _login("usage_quota@example.com")

    reply = client.post("/chat/message", headers=headers, json={"content": "hi"}).json()

    assert reply["available"] is False
    assert _events("usage_quota@example.com") == []


def test_gemini_usage_reads_sdk_fields_and_tolerates_absence():
    from types import SimpleNamespace

    from app.services.ai.gemini_provider import _usage

    meta = SimpleNamespace(prompt_token_count=11, candidates_token_count=4, total_token_count=15)
    assert _usage(SimpleNamespace(usage_metadata=meta), "m") == AIUsage("m", 11, 4, 15)
    assert _usage(SimpleNamespace(), "m") is None
    assert _usage(SimpleNamespace(usage_metadata=None), "m") is None
