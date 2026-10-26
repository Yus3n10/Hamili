"""
Hami's yes/no gestures and budget warnings come from the server's numbers.
These pin the thresholds, the affordability verdicts, and that the model's
own wording can never overrule them.
"""

from fastapi.testclient import TestClient

from app.core.clock import local_today
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.main import app
from app.models.user import User
from app.services.affordability_service import AffordabilityService, format_money
from app.services.agent_service import AgentService
from app.services.budget_rules import budget_alert_level

client = TestClient(app)


def _user_with(email: str, income: float, food_budget: float | None = None, food_spent: float = 0) -> dict:
    client.post("/auth/register", json={"email": email, "password": "SecurePass123", "preferred_name": "Ans"})
    token = client.post("/auth/login", json={"email": email, "password": "SecurePass123"}).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    cats = client.get("/categories", headers=headers).json()
    food = next(c["id"] for c in cats if c["name"] == "Food")
    salary = next(c["id"] for c in cats if c["name"] == "Salary")
    today = local_today().isoformat()
    client.post("/transactions", headers=headers, json={"category_id": salary, "amount": income, "type": "income", "transaction_date": today})
    if food_budget is not None:
        t = local_today()
        client.post("/budgets", headers=headers, json={"category_id": food, "month": t.month, "year": t.year, "limit_amount": food_budget})
    if food_spent:
        client.post("/transactions", headers=headers, json={"category_id": food, "amount": food_spent, "type": "expense", "transaction_date": today})
    return headers


def _check(email: str, amount: float, category: str | None = None):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        return AffordabilityService(db).check(user, amount, category)
    finally:
        db.close()


def test_alert_levels_follow_configured_thresholds(monkeypatch):
    assert budget_alert_level(59.9) == "ok"
    assert budget_alert_level(60) == "approaching"
    assert budget_alert_level(80) == "high"
    assert budget_alert_level(100) == "high"
    assert budget_alert_level(100.1) == "over"
    monkeypatch.setattr(get_settings(), "budget_warning_percent", 70.0)
    assert budget_alert_level(72) == "high"


def test_budget_response_carries_alert_level():
    headers = _user_with("ans_budget@example.com", income=5000, food_budget=1000, food_spent=850)
    t = local_today()
    budgets = client.get(f"/budgets?month={t.month}&year={t.year}", headers=headers).json()
    assert budgets[0]["percentage_used"] == 85.0
    assert budgets[0]["alert_level"] == "high"


def test_cannot_spend_more_than_available_balance():
    _user_with("ans_short@example.com", income=100)
    result = _check("ans_short@example.com", 500)
    assert result.answer == "negative"
    assert result.reply == "No, because you only have ₱100 available."


def test_can_spend_within_balance():
    _user_with("ans_enough@example.com", income=1000)
    result = _check("ans_enough@example.com", 50)
    assert result.answer == "affirmative"
    assert result.reply.startswith("Yes, you have ₱1,000 available")


def test_purchase_that_nearly_fills_budget_is_a_warning():
    _user_with("ans_warn@example.com", income=5000, food_budget=1000, food_spent=700)
    result = _check("ans_warn@example.com", 150, "food")
    assert result.answer == "warning"
    assert "85%" in result.reply


def test_purchase_past_budget_is_a_no_even_with_money():
    _user_with("ans_over@example.com", income=5000, food_budget=1000, food_spent=700)
    result = _check("ans_over@example.com", 400, "Food")
    assert result.answer == "negative"
    assert "₱300 left" in result.reply


def test_format_money():
    assert format_money(1234.5, "PHP") == "₱1,234.50"
    assert format_money(100, None) == "₱100"
    assert format_money(-20, "USD") == "-$20"


class _FakeProvider:
    def __init__(self, result: dict):
        self.result = result

    def interpret(self, *_args, **_kwargs) -> dict:
        return {**self.result, "usage": None}


def _respond(email: str, model_result: dict) -> dict:
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        agent = AgentService(db)
        agent.provider = _FakeProvider(model_result)
        return agent.respond(user, [{"role": "user", "content": "question"}])
    finally:
        db.close()


def test_server_verdict_overrides_model_wording():
    _user_with("ans_agent_no@example.com", income=100)
    out = _respond(
        "ans_agent_no@example.com",
        {"action": "check_affordability", "params": {"amount": 500}, "reply": "Yes, go for it!", "answer": "affirmative"},
    )
    assert out["answer"] == "negative"
    assert out["reply"] == "No, because you only have ₱100 available."


def test_affordability_without_amount_has_no_gesture():
    _user_with("ans_agent_noamt@example.com", income=100)
    out = _respond("ans_agent_noamt@example.com", {"action": "check_affordability", "params": {}, "reply": ""})
    assert out.get("answer") is None


def test_model_stance_passes_only_plain_yes_or_no():
    _user_with("ans_agent_stance@example.com", income=100)
    yes = _respond("ans_agent_stance@example.com", {"action": "none", "reply": "Yes, Food has a budget.", "answer": "affirmative"})
    assert yes["answer"] == "affirmative"
    warn = _respond("ans_agent_stance@example.com", {"action": "none", "reply": "Careful.", "answer": "warning"})
    assert warn["answer"] is None
    plain = _respond("ans_agent_stance@example.com", {"action": "none", "reply": "No worries, here's how budgets work."})
    assert plain["answer"] is None


def test_goal_contribution_is_a_savings_effect():
    assert AgentService._effect_for("contribute_to_goal", {"title": "x", "amount": 10}) == "savings"
