"""Agent action-execution contract tests.

The agent's `_execute` returns the list of app areas the client must refresh.
An expense affects a category's budget usage, so adding one must report
`budgets` (regression: it only reported `transactions`, leaving the budget
bar stale after Hami added an expense).
"""
from fastapi.testclient import TestClient

from app.db.session import SessionLocal
from app.main import app
from app.models.user import User
from app.services.agent_service import AgentService

client = TestClient(app)


def test_effect_for_transactions():
    assert AgentService._effect_for("add_transaction", {"type": "income"}) == "income"
    assert AgentService._effect_for("add_transaction", {"type": "expense"}) == "expense"
    assert AgentService._effect_for("add_transaction", {}) == "expense"
    assert AgentService._effect_for("set_budget", {"limit_amount": 100}) is None
    assert AgentService._effect_for("add_savings_goal", {"title": "x"}) is None


def _register(email: str) -> None:
    client.post(
        "/auth/register",
        json={"email": email, "password": "SecurePass123", "preferred_name": "Agent Test"},
    )


def test_add_expense_reports_budgets_changed():
    email = "agent_expense@example.com"
    _register(email)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        changed = AgentService(db)._execute(
            user,
            "add_transaction",
            {"type": "expense", "amount": 42.0, "category": "Food", "note": "unit-test"},
        )
        assert "transactions" in changed
        assert "budgets" in changed
    finally:
        db.rollback()
        db.close()


def test_add_income_does_not_report_budgets_changed():
    email = "agent_income@example.com"
    _register(email)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        changed = AgentService(db)._execute(
            user,
            "add_transaction",
            {"type": "income", "amount": 500.0, "category": "Salary"},
        )
        assert "transactions" in changed
        assert "budgets" not in changed
    finally:
        db.rollback()
        db.close()
