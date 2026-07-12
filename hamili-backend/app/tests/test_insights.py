"""
Insights endpoint contract tests. Generation calls the live Gemini API and
is non-deterministic (and failure-tolerant → may return []), so these assert
the endpoint contract, not AI content.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers() -> dict:
    email = "insights_test@example.com"
    password = "SecurePass123"
    client.post("/auth/register", json={"email": email, "password": password, "preferred_name": "Ins Test"})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_list_insights_returns_list():
    headers = _auth_headers()
    response = client.get("/insights", headers=headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_dismiss_missing_insight_returns_404():
    headers = _auth_headers()
    response = client.patch("/insights/999999/dismiss", headers=headers)
    assert response.status_code == 404
