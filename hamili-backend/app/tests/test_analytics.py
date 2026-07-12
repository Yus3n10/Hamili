from datetime import date

from fastapi.testclient import TestClient

from app.main import app
from app.services.analytics_service import month_window

client = TestClient(app)


def test_month_window_basic():
    # 6 months ending at 2026-07 -> Feb..Jul 2026, oldest first
    assert month_window(2026, 7, 6) == [
        (2026, 2), (2026, 3), (2026, 4), (2026, 5), (2026, 6), (2026, 7)
    ]


def test_month_window_crosses_year():
    assert month_window(2026, 2, 4) == [(2025, 11), (2025, 12), (2026, 1), (2026, 2)]


def test_month_window_single():
    assert month_window(2026, 7, 1) == [(2026, 7)]


def _auth_headers() -> dict:
    email = "analytics_test@example.com"
    password = "SecurePass123"
    client.post("/auth/register", json={"email": email, "password": password, "preferred_name": "Ana Test"})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_analytics_endpoints():
    headers = _auth_headers()
    cats = client.get("/categories", headers=headers).json()
    expense_cat = next(c for c in cats if c["type"] == "expense")
    income_cat = next(c for c in cats if c["type"] == "income")
    today = date.today()

    client.post("/transactions", headers=headers, json={
        "category_id": expense_cat["id"], "amount": 200.0, "type": "expense",
        "note": "a5-test", "transaction_date": today.isoformat()})
    client.post("/transactions", headers=headers, json={
        "category_id": income_cat["id"], "amount": 1000.0, "type": "income",
        "note": "a5-test", "transaction_date": today.isoformat()})

    # Monthly summary: net = income - expense for this month.
    summ = client.get(f"/analytics/summary?month={today.month}&year={today.year}", headers=headers).json()
    assert summ["income"] >= 1000.0
    assert summ["expense"] >= 200.0
    assert abs(summ["net"] - (summ["income"] - summ["expense"])) < 0.001

    # by-category returns the expense category with a positive total, sorted desc.
    cat_rows = client.get(f"/analytics/by-category?month={today.month}&year={today.year}", headers=headers).json()
    assert any(r["category_id"] == expense_cat["id"] and r["total"] >= 200.0 for r in cat_rows)
    totals = [r["total"] for r in cat_rows]
    assert totals == sorted(totals, reverse=True)

    # trend returns exactly 6 points ending at the current month.
    trend = client.get("/analytics/trend?months=6", headers=headers).json()
    assert len(trend) == 6
    assert trend[-1]["month"] == today.month and trend[-1]["year"] == today.year
