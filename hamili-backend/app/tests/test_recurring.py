from datetime import date

from fastapi.testclient import TestClient

from app.main import app
from app.services.recurring_service import advance_date

client = TestClient(app)


def test_weekly_advance():
    assert advance_date(date(2026, 7, 12), "weekly") == date(2026, 7, 19)


def test_monthly_advance_simple():
    assert advance_date(date(2026, 7, 12), "monthly") == date(2026, 8, 12)


def test_monthly_advance_clamps_month_end():
    # Jan 31 -> Feb 28 (2026 is not a leap year)
    assert advance_date(date(2026, 1, 31), "monthly") == date(2026, 2, 28)


def test_monthly_advance_year_rollover():
    assert advance_date(date(2026, 12, 15), "monthly") == date(2027, 1, 15)


def test_yearly_advance_leap_day_clamps():
    # Feb 29 2028 -> Feb 28 2029
    assert advance_date(date(2028, 2, 29), "yearly") == date(2029, 2, 28)


def _auth_headers() -> dict:
    email = "recurring_test@example.com"
    password = "SecurePass123"
    client.post("/auth/register", json={"email": email, "password": password, "preferred_name": "Rec Test"})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_recurring_crud_and_run_due():
    headers = _auth_headers()
    categories = client.get("/categories", headers=headers).json()
    income_cat = next(c for c in categories if c["type"] == "income")

    # Create an item already due today -> run-due should promote it.
    created = client.post(
        "/recurring",
        headers=headers,
        json={
            "type": "income",
            "name": "Integration Salary",
            "amount": 1234.00,
            "category_id": income_cat["id"],
            "frequency": "monthly",
            "next_due_date": date.today().isoformat(),
        },
    )
    assert created.status_code == 201
    item_id = created.json()["id"]

    run = client.post("/recurring/run-due", headers=headers)
    assert run.status_code == 200
    assert run.json()["promoted"] >= 1

    # After promotion, next_due_date has moved into the future.
    listed = client.get("/recurring", headers=headers).json()
    promoted_item = next(i for i in listed if i["id"] == item_id)
    assert promoted_item["next_due_date"] > date.today().isoformat()

    # A matching transaction now exists.
    txns = client.get("/transactions", headers=headers).json()
    assert any(t["note"] == "Integration Salary" and t["amount"] == 1234.0 for t in txns)

    # Cleanup.
    assert client.delete(f"/recurring/{item_id}", headers=headers).status_code == 204
