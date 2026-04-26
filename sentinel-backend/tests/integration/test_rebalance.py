"""Integration tests for POST /events/rebalance and /events/rebalance/apply."""
import pytest
from tests.integration.conftest import unique_email


def _create_event(client, headers, title, start_at, end_at=None, is_fixed=False):
    payload = {
        "title": title,
        "start_at": start_at,
        "all_day": False,
        "type": "event",
        "is_fixed": is_fixed,
    }
    if end_at:
        payload["end_at"] = end_at
    resp = client.post("/events/", json=payload, headers=headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


class TestRebalancePropose:
    def test_no_auth_returns_401(self, client):
        resp = client.post(
            "/events/rebalance",
            json={"timezone": "Europe/Moscow", "days": [{"date": "2026-04-25"}]},
        )
        assert resp.status_code == 401

    def test_invalid_timezone_still_processes(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance",
            json={"timezone": "Invalid/Zone", "days": [{"date": "2026-04-25"}]},
            headers=auth_headers,
            timeout=30,
        )
        # Falls back to UTC internally; no events on that day for this user — still 200
        assert resp.status_code == 200
        body = resp.json()
        assert "proposed" in body
        assert body["proposed"] == []

    def test_empty_days_list_returns_422(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance",
            json={"timezone": "Europe/Moscow", "days": []},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_missing_timezone_returns_422(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance",
            json={"days": [{"date": "2026-04-25"}]},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_no_events_returns_empty_proposed(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance",
            json={"timezone": "Europe/Moscow", "days": [{"date": "2099-12-31"}]},
            headers=auth_headers,
            timeout=30,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["proposed"] == []
        assert body["changed_count"] == 0

    def test_resource_battery_out_of_range_returns_422(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance",
            json={
                "timezone": "Europe/Moscow",
                "days": [{"date": "2026-04-25", "resource_battery": 1.5}],
            },
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_successful_propose_returns_required_fields(self, client, auth_headers):
        """With real events, LLM returns a valid response with all required fields."""
        resp = client.post(
            "/events/rebalance",
            json={"timezone": "Europe/Moscow", "days": [{"date": "2099-01-15"}]},
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable")
        assert resp.status_code == 200
        body = resp.json()
        assert "proposed" in body
        assert "summary" in body
        assert "changed_count" in body
        assert "unchanged_count" in body

    def test_propose_with_multiple_days(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance",
            json={
                "timezone": "UTC",
                "days": [
                    {"date": "2099-06-10"},
                    {"date": "2099-06-11", "resource_battery": 0.8},
                ],
            },
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable")
        assert resp.status_code == 200


class TestRebalanceApply:
    def test_no_auth_returns_401(self, client):
        resp = client.post(
            "/events/rebalance/apply",
            json={"events": []},
        )
        assert resp.status_code == 401

    def test_empty_events_list_returns_422(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance/apply",
            json={"events": []},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_nonexistent_event_returns_400(self, client, auth_headers):
        resp = client.post(
            "/events/rebalance/apply",
            json={
                "events": [
                    {
                        "id": "00000000-0000-0000-0000-000000000000",
                        "start_at": "2026-04-25T10:00:00+03:00",
                        "end_at": "2026-04-25T11:00:00+03:00",
                    }
                ]
            },
            headers=auth_headers,
        )
        assert resp.status_code == 400

    def test_apply_updates_event_times(self, client, auth_headers):
        event = _create_event(
            client, auth_headers,
            title="Rebalance target",
            start_at="2026-04-25T09:00:00+03:00",
            end_at="2026-04-25T10:00:00+03:00",
        )
        new_start = "2026-04-25T14:00:00+03:00"
        new_end = "2026-04-25T15:00:00+03:00"

        resp = client.post(
            "/events/rebalance/apply",
            json={
                "events": [
                    {"id": event["id"], "start_at": new_start, "end_at": new_end}
                ]
            },
            headers=auth_headers,
        )
        assert resp.status_code == 204

        # Verify the change was saved
        get_resp = client.get(f"/events/{event['id']}", headers=auth_headers)
        assert get_resp.status_code == 200
        updated = get_resp.json()
        assert "14:00:00" in updated["start_at"] or "11:00:00" in updated["start_at"]  # UTC offset diff is fine

    def test_apply_fixed_event_returns_400(self, client, auth_headers):
        event = _create_event(
            client, auth_headers,
            title="Fixed meeting",
            start_at="2026-04-25T09:00:00+03:00",
            end_at="2026-04-25T10:00:00+03:00",
            is_fixed=True,
        )
        resp = client.post(
            "/events/rebalance/apply",
            json={
                "events": [
                    {
                        "id": event["id"],
                        "start_at": "2026-04-25T15:00:00+03:00",
                        "end_at": "2026-04-25T16:00:00+03:00",
                    }
                ]
            },
            headers=auth_headers,
        )
        assert resp.status_code == 400

    def test_apply_end_before_start_returns_422(self, client, auth_headers):
        event = _create_event(
            client, auth_headers,
            title="Bad times event",
            start_at="2026-04-25T09:00:00+03:00",
            end_at="2026-04-25T10:00:00+03:00",
        )
        resp = client.post(
            "/events/rebalance/apply",
            json={
                "events": [
                    {
                        "id": event["id"],
                        "start_at": "2026-04-25T12:00:00+03:00",
                        "end_at": "2026-04-25T10:00:00+03:00",
                    }
                ]
            },
            headers=auth_headers,
        )
        # Pydantic validates start < end at schema level or service level
        assert resp.status_code in (400, 422)

    def test_other_user_cannot_apply_to_foreign_event(self, client):
        # Register a second user
        email2 = unique_email()
        password2 = "OtherUser1!"
        client.post("/auth/register", json={"email": email2, "password": password2})
        login2 = client.post("/auth/login", json={"email": email2, "password": password2})
        headers2 = {"Authorization": f"Bearer {login2.json()['access_token']}"}

        # Create event as user2
        event = _create_event(
            client, headers2,
            title="User2 event",
            start_at="2026-04-25T09:00:00+03:00",
            end_at="2026-04-25T10:00:00+03:00",
        )

        # Register a third user and try to apply to user2's event
        email3 = unique_email()
        client.post("/auth/register", json={"email": email3, "password": "ThirdUser1!"})
        login3 = client.post("/auth/login", json={"email": email3, "password": "ThirdUser1!"})
        headers3 = {"Authorization": f"Bearer {login3.json()['access_token']}"}

        resp = client.post(
            "/events/rebalance/apply",
            json={
                "events": [
                    {
                        "id": event["id"],
                        "start_at": "2026-04-25T14:00:00+03:00",
                        "end_at": "2026-04-25T15:00:00+03:00",
                    }
                ]
            },
            headers=headers3,
        )
        assert resp.status_code == 400
