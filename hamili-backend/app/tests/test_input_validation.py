"""
Input edge cases that used to be accepted or crash: email case, categories
that don't exist or don't match the money direction, null in partial
updates, out-of-range periods, and unlimited AI refreshes.
"""

from fastapi.testclient import TestClient

from app.core.rate_limit import limiter
from app.main import app

client = TestClient(app, raise_server_exceptions=False)
PASSWORD = "SecurePass123"


def _headers(email: str) -> dict:
    client.post("/auth/register", json={"email": email, "password": PASSWORD, "preferred_name": "Val"})
    token = client.post("/auth/login", json={"email": email, "password": PASSWORD}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _categories(headers: dict) -> dict[str, int]:
    return {c["name"]: c["id"] for c in client.get("/categories", headers=headers).json()}


def test_email_is_case_insensitive_for_register_and_login():
    first = client.post("/auth/register", json={"email": "Case.User@Example.com", "password": PASSWORD, "preferred_name": "A"})
    dup = client.post("/auth/register", json={"email": "case.user@example.com", "password": PASSWORD, "preferred_name": "B"})
    login = client.post("/auth/login", json={"email": "CASE.USER@EXAMPLE.COM", "password": PASSWORD})

    assert first.status_code == 201
    assert first.json()["email"] == "case.user@example.com"
    assert dup.status_code == 400
    assert login.status_code == 200


def test_transaction_with_unknown_category_is_rejected():
    headers = _headers("val_unknown_cat@example.com")
    response = client.post(
        "/transactions",
        headers=headers,
        json={"category_id": 99999, "amount": 10, "type": "expense", "transaction_date": "2026-10-26"},
    )
    assert response.status_code == 422


def test_expense_cannot_use_an_income_category():
    headers = _headers("val_type_mismatch@example.com")
    salary = _categories(headers)["Salary"]
    response = client.post(
        "/transactions",
        headers=headers,
        json={"category_id": salary, "amount": 10, "type": "expense", "transaction_date": "2026-10-26"},
    )
    assert response.status_code == 422


def test_editing_a_transaction_into_a_mismatched_category_is_rejected():
    headers = _headers("val_edit_mismatch@example.com")
    cats = _categories(headers)
    txn = client.post(
        "/transactions",
        headers=headers,
        json={"category_id": cats["Food"], "amount": 10, "type": "expense", "transaction_date": "2026-10-26"},
    ).json()
    response = client.patch(f"/transactions/{txn['id']}", headers=headers, json={"category_id": cats["Salary"]})
    assert response.status_code == 422


def test_budget_must_use_an_expense_category():
    headers = _headers("val_budget_cat@example.com")
    cats = _categories(headers)
    income = client.post(
        "/budgets", headers=headers, json={"category_id": cats["Salary"], "month": 10, "year": 2026, "limit_amount": 100}
    )
    unknown = client.post(
        "/budgets", headers=headers, json={"category_id": 99999, "month": 10, "year": 2026, "limit_amount": 100}
    )
    assert income.status_code == 422
    assert unknown.status_code == 422


def test_recurring_item_category_must_match_its_type():
    headers = _headers("val_recurring_cat@example.com")
    food = _categories(headers)["Food"]
    response = client.post(
        "/recurring",
        headers=headers,
        json={"type": "income", "name": "Pay", "amount": 10, "category_id": food, "frequency": "monthly", "next_due_date": "2030-01-01"},
    )
    assert response.status_code == 422


def test_null_in_goal_update_does_not_crash():
    headers = _headers("val_goal_null@example.com")
    goal = client.post("/goals", headers=headers, json={"title": "Bike", "target_amount": 1000}).json()

    response = client.patch(f"/goals/{goal['id']}", headers=headers, json={"title": None, "target_amount": None})

    assert response.status_code == 200
    assert (response.json()["title"], response.json()["target_amount"]) == ("Bike", 1000.0)


def test_goal_target_date_can_still_be_cleared():
    headers = _headers("val_goal_date@example.com")
    goal = client.post("/goals", headers=headers, json={"title": "Trip", "target_amount": 500, "target_date": "2030-01-01"}).json()

    response = client.patch(f"/goals/{goal['id']}", headers=headers, json={"target_date": None})

    assert response.json()["target_date"] is None


def test_null_in_recurring_update_does_not_crash():
    headers = _headers("val_recurring_null@example.com")
    ent = _categories(headers)["Entertainment"]
    item = client.post(
        "/recurring",
        headers=headers,
        json={"type": "expense", "name": "Stream", "amount": 10, "category_id": ent, "frequency": "monthly", "next_due_date": "2030-01-01"},
    ).json()

    response = client.patch(f"/recurring/{item['id']}", headers=headers, json={"name": None})

    assert response.status_code == 200
    assert response.json()["name"] == "Stream"


def test_lowering_a_goal_target_below_savings_completes_it():
    headers = _headers("val_goal_complete@example.com")
    goal = client.post("/goals", headers=headers, json={"title": "Phone", "target_amount": 1000}).json()
    client.post(f"/goals/{goal['id']}/contribute", headers=headers, json={"amount": 600})

    lowered = client.patch(f"/goals/{goal['id']}", headers=headers, json={"target_amount": 500}).json()
    raised = client.patch(f"/goals/{goal['id']}", headers=headers, json={"target_amount": 2000}).json()

    assert lowered["status"] == "completed"
    assert raised["status"] == "in_progress"


def test_period_parameters_are_range_checked():
    headers = _headers("val_periods@example.com")
    assert client.get("/analytics/trend?months=100000", headers=headers).status_code == 422
    assert client.get("/analytics/trend?months=0", headers=headers).status_code == 422
    assert client.get("/budgets?month=13&year=2026", headers=headers).status_code == 422
    assert client.get("/analytics/summary?month=0&year=2026", headers=headers).status_code == 422


def test_insight_refresh_is_rate_limited():
    headers = _headers("val_ai_limit@example.com")
    limiter.enabled = True
    limiter.reset()
    try:
        codes = [client.post("/insights/refresh", headers=headers).status_code for _ in range(25)]
    finally:
        limiter.enabled = False
    assert 429 in codes


def test_goal_estimate_is_not_absurd_on_day_one():
    """A goal funded on the day it was made used to project completion in
    about two days, because the elapsed time floor was one day."""
    from datetime import date

    headers = _headers("val_goal_estimate@example.com")
    goal = client.post("/goals", headers=headers, json={"title": "Fund", "target_amount": 50000}).json()
    funded = client.post(f"/goals/{goal['id']}/contribute", headers=headers, json={"amount": 18500}).json()

    days_out = (date.fromisoformat(funded["estimated_completion_date"]) - date.today()).days
    assert days_out >= 30
