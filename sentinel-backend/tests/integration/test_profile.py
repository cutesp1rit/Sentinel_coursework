import uuid
import pytest


def _register_and_login(client) -> dict:
    email = f"profile_test_{uuid.uuid4().hex[:8]}@example.com"
    password = "StrongPass1!"
    client.post("/auth/register", json={"email": email, "password": password})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


class TestGetMe:
    def test_returns_ai_instructions_field(self, client, auth_headers):
        resp = client.get("/auth/me", headers=auth_headers)
        assert resp.status_code == 200
        assert "ai_instructions" in resp.json()

    def test_ai_instructions_null_by_default(self, client, auth_headers):
        resp = client.get("/auth/me", headers=auth_headers)
        assert resp.json()["ai_instructions"] is None


class TestUpdateProfile:
    def test_set_ai_instructions(self, client):
        headers = _register_and_login(client)
        resp = client.patch("/auth/me", json={"ai_instructions": "Always be concise."}, headers=headers)
        assert resp.status_code == 200
        assert resp.json()["ai_instructions"] == "Always be concise."

    def test_ai_instructions_persisted(self, client):
        headers = _register_and_login(client)
        client.patch("/auth/me", json={"ai_instructions": "Use formal tone."}, headers=headers)
        me = client.get("/auth/me", headers=headers)
        assert me.json()["ai_instructions"] == "Use formal tone."

    def test_clear_ai_instructions(self, client):
        headers = _register_and_login(client)
        client.patch("/auth/me", json={"ai_instructions": "Some instructions."}, headers=headers)
        resp = client.patch("/auth/me", json={"ai_instructions": None}, headers=headers)
        assert resp.status_code == 200
        assert resp.json()["ai_instructions"] is None

    def test_update_timezone(self, client):
        headers = _register_and_login(client)
        resp = client.patch("/auth/me", json={"timezone": "America/New_York"}, headers=headers)
        assert resp.status_code == 200
        assert resp.json()["timezone"] == "America/New_York"

    def test_update_locale(self, client):
        headers = _register_and_login(client)
        resp = client.patch("/auth/me", json={"locale": "en-US"}, headers=headers)
        assert resp.status_code == 200
        assert resp.json()["locale"] == "en-US"

    def test_partial_update_does_not_reset_other_fields(self, client):
        headers = _register_and_login(client)
        client.patch("/auth/me", json={"ai_instructions": "Be brief.", "timezone": "Europe/London"}, headers=headers)
        client.patch("/auth/me", json={"locale": "en-GB"}, headers=headers)
        me = client.get("/auth/me", headers=headers)
        body = me.json()
        assert body["ai_instructions"] == "Be brief."
        assert body["timezone"] == "Europe/London"
        assert body["locale"] == "en-GB"

    def test_ai_instructions_max_length(self, client):
        headers = _register_and_login(client)
        long_text = "a" * 501
        resp = client.patch("/auth/me", json={"ai_instructions": long_text}, headers=headers)
        assert resp.status_code == 422

    def test_empty_body_is_noop(self, client, auth_headers):
        before = client.get("/auth/me", headers=auth_headers).json()
        resp = client.patch("/auth/me", json={}, headers=auth_headers)
        assert resp.status_code == 200
        after = resp.json()
        assert after["timezone"] == before["timezone"]
        assert after["locale"] == before["locale"]

    def test_no_auth_returns_401(self, client):
        resp = client.patch("/auth/me", json={"ai_instructions": "test"})
        assert resp.status_code == 401
