import pytest


FUTURE_EVENT = {
    "title": "Team meeting",
    "description": "Weekly sync",
    "start_at": "2026-04-10T10:00:00",
    "end_at": "2026-04-10T11:00:00",
    "all_day": False,
    "type": "event",
    "location": "Room 1",
    "is_fixed": False,
    "source": "user",
}

REMINDER = {
    "title": "Take pills",
    "start_at": "2026-04-11T08:00:00",
    "all_day": False,
    "type": "reminder",
    "is_fixed": False,
    "source": "user",
}


@pytest.fixture(scope="module")
def created_event(client, auth_headers):
    resp = client.post("/events", json=FUTURE_EVENT, headers=auth_headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


class TestCreateEvent:
    def test_create_event_success(self, client, auth_headers):
        resp = client.post("/events", json=FUTURE_EVENT, headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["title"] == FUTURE_EVENT["title"]
        assert body["source"] == "user"
        assert "id" in body
        assert "user_id" in body

    def test_create_reminder_no_end_at(self, client, auth_headers):
        resp = client.post("/events", json=REMINDER, headers=auth_headers)
        assert resp.status_code == 201
        assert resp.json()["type"] == "reminder"
        assert resp.json()["end_at"] is None

    def test_create_event_no_auth(self, client):
        resp = client.post("/events", json=FUTURE_EVENT)
        assert resp.status_code == 401


class TestGetEvents:
    def test_list_events(self, client, auth_headers, created_event):
        resp = client.get("/events", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "items" in body
        assert "total" in body
        assert body["total"] >= 1

    def test_list_events_date_filter(self, client, auth_headers, created_event):
        resp = client.get(
            "/events",
            params={"date_from": "2026-04-10T00:00:00", "date_to": "2026-04-10T23:59:59"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        items = resp.json()["items"]
        assert any(e["id"] == created_event["id"] for e in items)

    def test_list_events_empty_range(self, client, auth_headers):
        resp = client.get(
            "/events",
            params={"date_from": "2000-01-01T00:00:00", "date_to": "2000-01-02T00:00:00"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["total"] == 0

    def test_get_single_event(self, client, auth_headers, created_event):
        event_id = created_event["id"]
        resp = client.get(f"/events/{event_id}", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["id"] == event_id

    def test_get_nonexistent_event(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        resp = client.get(f"/events/{fake_id}", headers=auth_headers)
        assert resp.status_code == 404

    def test_isolation_between_users(self, client, registered_user):
        email2 = f"test_{__import__('uuid').uuid4().hex[:8]}@example.com"
        client.post("/auth/register", json={"email": email2, "password": "StrongPass1!"})
        login = client.post("/auth/login", json={"email": email2, "password": "StrongPass1!"})
        token2 = login.json()["access_token"]
        headers2 = {"Authorization": f"Bearer {token2}"}

        resp = client.get("/events", headers=headers2)
        assert resp.status_code == 200
        assert resp.json()["total"] == 0


class TestUpdateEvent:
    def test_patch_title(self, client, auth_headers, created_event):
        event_id = created_event["id"]
        resp = client.patch(
            f"/events/{event_id}",
            json={"title": "Updated Title"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["title"] == "Updated Title"

    def test_patch_partial(self, client, auth_headers, created_event):
        event_id = created_event["id"]
        resp = client.patch(
            f"/events/{event_id}",
            json={"location": "Online"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["location"] == "Online"

    def test_patch_nonexistent(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        resp = client.patch(f"/events/{fake_id}", json={"title": "X"}, headers=auth_headers)
        assert resp.status_code == 404


class TestDeleteEvent:
    def test_delete_event(self, client, auth_headers):
        resp = client.post("/events", json=FUTURE_EVENT, headers=auth_headers)
        event_id = resp.json()["id"]

        del_resp = client.delete(f"/events/{event_id}", headers=auth_headers)
        assert del_resp.status_code == 204

        get_resp = client.get(f"/events/{event_id}", headers=auth_headers)
        assert get_resp.status_code == 404

    def test_delete_nonexistent(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        resp = client.delete(f"/events/{fake_id}", headers=auth_headers)
        assert resp.status_code == 404
