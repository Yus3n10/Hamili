"""
The snapshot is all Hami knows about the user's money, so it must name
categories and say how much of each budget is used. Bare category ids and
limits without spending leave the model guessing.
"""

from fastapi.testclient import TestClient

from app.core.clock import local_today
from app.db.session import SessionLocal
from app.main import app
from app.models.user import User
from app.services.insight_service import InsightService

client = TestClient(app)


def test_snapshot_names_categories_and_shows_budget_use():
    email = "snapshot_test@example.com"
    client.post("/auth/register", json={"email": email, "password": "SecurePass123", "preferred_name": "Snap"})
    token = client.post("/auth/login", json={"email": email, "password": "SecurePass123"}).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    food = next(c["id"] for c in client.get("/categories", headers=headers).json() if c["name"] == "Food")
    today = local_today()
    client.post("/budgets", headers=headers, json={"category_id": food, "month": today.month, "year": today.year, "limit_amount": 1000})
    client.post(
        "/transactions",
        headers=headers,
        json={"category_id": food, "amount": 250, "type": "expense", "transaction_date": today.isoformat()},
    )

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        snapshot = InsightService(db).build_financial_snapshot(user)
    finally:
        db.close()

    assert snapshot["recent_transactions"][0]["category"] == "Food"
    assert snapshot["budgets"] == [{"category": "Food", "limit": 1000.0, "spent": 250.0}]
