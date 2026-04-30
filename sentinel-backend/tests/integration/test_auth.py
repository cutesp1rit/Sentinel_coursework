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


class TestVerifyEmail:
    def test_invalid_token_returns_400(self, client):
        resp = client.post("/auth/verify-email", json={"token": "invalid_token_xyz"})
        assert resp.status_code == 400

    def test_missing_token_returns_422(self, client):
        resp = client.post("/auth/verify-email", json={})
        assert resp.status_code == 422


class TestResendVerification:
    def test_unknown_email_returns_200(self, client):
        resp = client.post("/auth/resend-verification", json={"email": "nobody@example.com"})
        assert resp.status_code == 200

    def test_already_verified_user_returns_400(self, client, registered_user):
        resp = client.post("/auth/resend-verification", json={"email": registered_user["email"]})
        assert resp.status_code == 400

    def test_missing_email_returns_422(self, client):
        resp = client.post("/auth/resend-verification", json={})
        assert resp.status_code == 422


class TestForgotPassword:
    def test_known_email_returns_200(self, client, registered_user):
        resp = client.post("/auth/forgot-password", json={"email": registered_user["email"]})
        assert resp.status_code == 200

    def test_unknown_email_returns_200(self, client):
        resp = client.post("/auth/forgot-password", json={"email": "nobody@example.com"})
        assert resp.status_code == 200

    def test_missing_email_returns_422(self, client):
        resp = client.post("/auth/forgot-password", json={})
        assert resp.status_code == 422


class TestResetPassword:
    def test_invalid_token_returns_400(self, client):
        resp = client.post("/auth/reset-password", json={"token": "bad_token", "new_password": "NewPass1!"})
        assert resp.status_code == 400

    def test_missing_fields_returns_422(self, client):
        resp = client.post("/auth/reset-password", json={"token": "only_token"})
        assert resp.status_code == 422


class TestDeleteAccount:
    def _create_and_login(self, client) -> tuple[str, dict]:
        """Register a fresh user and return (password, auth_headers)."""
        email = unique_email()
        password = "DeleteMe1!"
        client.post("/auth/register", json={"email": email, "password": password})
        resp = client.post("/auth/login", json={"email": email, "password": password})
        token = resp.json()["access_token"]
        return password, {"Authorization": f"Bearer {token}"}

    def test_delete_with_correct_password_returns_204(self, client):
        password, headers = self._create_and_login(client)
        resp = client.request("DELETE", "/auth/me", json={"password": password}, headers=headers)
        assert resp.status_code == 204

    def test_delete_with_wrong_password_returns_400(self, client):
        _, headers = self._create_and_login(client)
        resp = client.request("DELETE", "/auth/me", json={"password": "WrongPass999!"}, headers=headers)
        assert resp.status_code == 400

    def test_delete_without_auth_returns_401(self, client):
        resp = client.request("DELETE", "/auth/me", json={"password": "anything"})
        assert resp.status_code == 401

    def test_token_invalid_after_deletion(self, client):
        password, headers = self._create_and_login(client)
        client.request("DELETE", "/auth/me", json={"password": password}, headers=headers)
        # The deleted user's token must no longer grant access
        resp = client.get("/auth/me", headers=headers)
        assert resp.status_code == 401
