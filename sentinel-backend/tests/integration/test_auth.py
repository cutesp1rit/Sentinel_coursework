import pytest
from tests.integration.conftest import unique_email


class TestRegister:
    def test_register_success(self, client):
        resp = client.post(
            "/auth/register",
            json={"email": unique_email(), "password": "ValidPass1!"},
        )
        assert resp.status_code == 201
        body = resp.json()
        assert "id" in body
        assert "password" not in body
        assert "password_hash" not in body
        assert body["email"].endswith("@example.com")

    def test_register_duplicate_email(self, client, registered_user):
        resp = client.post(
            "/auth/register",
            json={"email": registered_user["email"], "password": "AnotherPass1!"},
        )
        assert resp.status_code == 409

    def test_register_short_password(self, client):
        resp = client.post(
            "/auth/register",
            json={"email": unique_email(), "password": "short"},
        )
        assert resp.status_code == 422

    def test_register_invalid_email(self, client):
        resp = client.post(
            "/auth/register",
            json={"email": "not-an-email", "password": "ValidPass1!"},
        )
        assert resp.status_code == 422

    def test_register_missing_fields(self, client):
        resp = client.post("/auth/register", json={})
        assert resp.status_code == 422


class TestLogin:
    def test_login_success(self, client, registered_user):
        resp = client.post(
            "/auth/login",
            json={
                "email": registered_user["email"],
                "password": registered_user["password"],
            },
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert body["token_type"] == "bearer"

    def test_login_wrong_password(self, client, registered_user):
        resp = client.post(
            "/auth/login",
            json={"email": registered_user["email"], "password": "WrongPass999!"},
        )
        assert resp.status_code == 401

    def test_login_unknown_email(self, client):
        resp = client.post(
            "/auth/login",
            json={"email": "ghost@example.com", "password": "ValidPass1!"},
        )
        assert resp.status_code == 401

    def test_login_missing_fields(self, client):
        resp = client.post("/auth/login", json={"email": "only@email.com"})
        assert resp.status_code == 422


class TestProtectedEndpoints:
    def test_no_token_returns_401(self, client):
        resp = client.get("/events")
        assert resp.status_code == 401

    def test_invalid_token_returns_401(self, client):
        resp = client.get("/events", headers={"Authorization": "Bearer totally.fake.token"})
        assert resp.status_code == 401
