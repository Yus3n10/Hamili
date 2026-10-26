"""
The admin console API: owner-only, read-only, counts only. Anyone else must
not even learn the routes exist, and no response may carry money, notes or
chat text.
"""

import pytest
from fastapi.testclient import TestClient

from app.core.clock import local_today
from app.core.config import Settings, get_settings
from app.db.session import SessionLocal
from app.main import app
from app.models.activity import AdminAccessLog, AIUsageEvent, UserActivityDay
from app.models.user import User

client = TestClient(app)
PASSWORD = "SecurePass123"

TESTER_FIELDS = {
    "id", "name", "email", "joined_at", "last_active_at", "days_active_30d",
    "transactions_count", "budgets_count", "goals_count", "hami_messages_total",
    "hami_tokens_total", "hami_tokens_7d", "hami_tokens_chat", "hami_tokens_insight",
}


def _login(email: str, name: str = "Tester") -> tuple[int, dict]:
    client.post("/auth/register", json={"email": email, "password": PASSWORD, "preferred_name": name})
    token = client.post("/auth/login", json={"email": email, "password": PASSWORD}).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    return client.get("/auth/me", headers=headers).json()["id"], headers


@pytest.fixture
def admin(monkeypatch):
    admin_id, headers = _login("admin_owner@example.com", "Owner")
    monkeypatch.setattr(get_settings(), "admin_user_ids", f" {admin_id}, ")
    return admin_id, headers


def _log_rows(admin_id: int) -> list[AdminAccessLog]:
    db = SessionLocal()
    try:
        return db.query(AdminAccessLog).filter(AdminAccessLog.admin_user_id == admin_id).all()
    finally:
        db.close()


def test_admin_ids_parse_with_spaces_and_trailing_comma():
    assert Settings(database_url="sqlite://", secret_key="x", admin_user_ids="3, 7,").admin_id_set == {3, 7}
    assert Settings(database_url="sqlite://", secret_key="x", admin_user_ids="").admin_id_set == set()
    assert Settings(database_url="sqlite://", secret_key="x", admin_user_ids=" , x, 4").admin_id_set == {4}


def test_non_admin_gets_404_and_no_log_row(admin):
    tester_id, headers = _login("admin_nonadmin@example.com")

    for path in ("/admin/overview", "/admin/testers", "/admin/access-log"):
        assert client.get(path, headers=headers).status_code == 404
    assert _log_rows(tester_id) == []


def test_missing_or_bad_token_gets_404():
    unknown = client.get("/admin/definitely-not-a-route")
    assert client.get("/admin/overview").status_code == unknown.status_code == 404
    assert client.get("/admin/overview", headers={"Authorization": "Bearer garbage"}).status_code == 404


def test_me_reports_is_admin(admin):
    _, admin_headers = admin
    _, tester_headers = _login("admin_me_tester@example.com")

    assert client.get("/auth/me", headers=admin_headers).json()["is_admin"] is True
    assert client.get("/auth/me", headers=tester_headers).json()["is_admin"] is False
    assert client.patch("/auth/me", headers=admin_headers, json={"preferred_name": "Owner"}).json()["is_admin"] is True


def test_overview_counts_exclude_admin(admin):
    _, admin_headers = admin
    before = client.get("/admin/overview", headers=admin_headers).json()

    _login("admin_overview_new@example.com")
    after = client.get("/admin/overview", headers=admin_headers).json()

    assert after["testers_total"] == before["testers_total"] + 1
    assert after["active_today"] == before["active_today"] + 1
    assert after["new_7d"] == before["new_7d"] + 1
    assert len(after["daily"]) == 30
    assert after["daily"][-1]["day"] == local_today().isoformat()
    assert all(row["email"] != "admin_owner@example.com" for row in client.get(
        "/admin/testers", headers=admin_headers, params={"page_size": 100}).json()["items"])


def test_testers_rows_have_counts_and_no_money_fields(admin):
    _, admin_headers = admin
    tester_id, headers = _login("admin_rows@example.com", "Rowan")
    food = next(c["id"] for c in client.get("/categories", headers=headers).json() if c["name"] == "Food")
    client.post("/transactions", headers=headers, json={
        "category_id": food, "amount": 999, "type": "expense", "note": "secret note", "transaction_date": "2026-10-20",
    })
    db = SessionLocal()
    db.add_all([
        AIUsageEvent(user_id=tester_id, kind="chat", total_tokens=100),
        AIUsageEvent(user_id=tester_id, kind="insight", total_tokens=40),
    ])
    db.commit()
    db.close()

    page = client.get("/admin/testers", headers=admin_headers, params={"search": "admin_rows@"}).json()
    [row] = page["items"]

    assert set(row) == TESTER_FIELDS
    assert "999" not in str(row) and "secret note" not in str(row)
    assert (row["name"], row["transactions_count"], row["hami_messages_total"]) == ("Rowan", 1, 1)
    assert (row["hami_tokens_total"], row["hami_tokens_chat"], row["hami_tokens_insight"]) == (140, 100, 40)


def test_never_active_tester_has_null_last_active_and_zero_counts(admin):
    _, admin_headers = admin
    client.post("/auth/register", json={"email": "admin_ghost@example.com", "password": PASSWORD, "preferred_name": "Ghost"})

    [row] = client.get("/admin/testers", headers=admin_headers, params={"search": "admin_ghost@"}).json()["items"]

    assert row["last_active_at"] is None
    assert (row["days_active_30d"], row["transactions_count"], row["hami_tokens_total"]) == (0, 0, 0)


def test_search_treats_percent_literally(admin):
    _, admin_headers = admin
    _login("admin_pct@example.com", "100% Saver")
    _login("admin_plain@example.com", "1000 Saver")

    names = [r["name"] for r in client.get(
        "/admin/testers", headers=admin_headers, params={"search": "100%"}).json()["items"]]

    assert names == ["100% Saver"]


def test_admin_responses_are_no_store_and_logged(admin):
    admin_id, admin_headers = admin
    before = len(_log_rows(admin_id))

    response = client.get("/admin/overview", headers=admin_headers)

    assert response.headers["cache-control"] == "no-store"
    assert len(_log_rows(admin_id)) == before + 1


def test_access_log_lists_admin_paths(admin):
    _, admin_headers = admin
    client.get("/admin/testers", headers=admin_headers)

    items = client.get("/admin/access-log", headers=admin_headers).json()["items"]

    assert items[0]["path"] == "/admin/access-log"
    assert any(item["path"] == "/admin/testers" for item in items)


def test_page_size_capped_at_100(admin):
    _, admin_headers = admin
    assert client.get("/admin/testers", headers=admin_headers, params={"page_size": 101}).status_code == 422
    assert client.get("/admin/testers", headers=admin_headers, params={"sort": "email"}).status_code == 422


def test_admin_activity_does_not_count_as_tester_activity(admin):
    admin_id, admin_headers = admin
    db = SessionLocal()
    db.query(User).filter(User.id == admin_id).update({User.last_active_at: None})
    db.query(UserActivityDay).filter(UserActivityDay.user_id == admin_id).delete()
    db.commit()
    db.close()
    before = client.get("/admin/overview", headers=admin_headers).json()

    client.get("/auth/me", headers=admin_headers)
    after = client.get("/admin/overview", headers=admin_headers).json()

    assert (after["testers_total"], after["active_today"]) == (before["testers_total"], before["active_today"])


def test_admin_timestamps_always_carry_a_timezone(admin):
    """SQLite returns naive datetimes; without an offset the app reads UTC
    as local time (8 hours off in Manila)."""
    _, admin_headers = admin
    _login("admin_tz@example.com")

    [row] = client.get("/admin/testers", headers=admin_headers, params={"search": "admin_tz@"}).json()["items"]
    [entry, *_] = client.get("/admin/access-log", headers=admin_headers).json()["items"]

    for value in (row["joined_at"], row["last_active_at"], entry["created_at"]):
        assert value.endswith("Z") or value.endswith("+00:00"), value
