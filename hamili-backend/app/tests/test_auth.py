"""
Smoke tests for the auth flow. Run with: pytest
Requires a test database configured via DATABASE_URL in the test env.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_register_and_login():
    register_payload = {
        "email": "test_user@example.com",
        "password": "SecurePass123",
        "preferred_name": "Test User",
    }
    register_response = client.post("/auth/register", json=register_payload)
    assert register_response.status_code in (201, 400)  # 400 if already seeded from a prior run

    login_response = client.post(
        "/auth/login",
        json={"email": register_payload["email"], "password": register_payload["password"]},
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()
