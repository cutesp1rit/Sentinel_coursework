import uuid
import pytest


BASE_EVENT = {
    "title": "Sync event",
    "start_at": "2026-05-01T10:00:00",
    "end_at": "2026-05-01T11:00:00",
    "all_day": False,
    "type": "event",
    "is_fixed": False,
    "source": "user",
}


def _create_event(client, auth_headers, overrides=None) -> dict:
    data = {**BASE_EVENT, **(overrides or {})}
    resp = client.post("/events", json=data, headers=auth_headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


class TestSyncCreate:
    def test_create_single_event(self, client, auth_headers):
        resp = client.post("/events/sync", json={"upserts": [BASE_EVENT], "deletes": []}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["created"]) == 1
        assert len(body["updated"]) == 0
        assert len(body["deleted"]) == 0
        created = body["created"][0]
        assert created["title"] == BASE_EVENT["title"]
        assert "id" in created

    def test_create_assigns_backend_id(self, client, auth_headers):
        resp = client.post("/events/sync", json={"upserts": [BASE_EVENT]}, headers=auth_headers)
        assert resp.status_code == 200
        created_id = resp.json()["created"][0]["id"]
        get_resp = client.get(f"/events/{created_id}", headers=auth_headers)
        assert get_resp.status_code == 200

    def test_create_multiple_events(self, client, auth_headers):
        upserts = [
            {**BASE_EVENT, "title": "Event A"},
            {**BASE_EVENT, "title": "Event B"},
            {**BASE_EVENT, "title": "Event C"},
        ]
        resp = client.post("/events/sync", json={"upserts": upserts}, headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()["created"]) == 3

    def test_all_created_ids_are_fetchable(self, client, auth_headers):
        upserts = [
            {**BASE_EVENT, "title": "Offline A"},
            {**BASE_EVENT, "title": "Offline B"},
            {**BASE_EVENT, "title": "Offline C"},
        ]
        resp = client.post("/events/sync", json={"upserts": upserts}, headers=auth_headers)
        created = resp.json()["created"]
        assert len(created) == 3

        for event in created:
            get_resp = client.get(f"/events/{event['id']}", headers=auth_headers)
            assert get_resp.status_code == 200
            assert get_resp.json()["title"] == event["title"]

    def test_create_reminder_no_end_at(self, client, auth_headers):
        reminder = {"title": "Take pills", "start_at": "2026-05-01T08:00:00", "type": "reminder", "source": "user"}
        resp = client.post("/events/sync", json={"upserts": [reminder]}, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["created"][0]["end_at"] is None

    def test_create_with_unknown_id_gets_new_id(self, client, auth_headers):
        # If client sends an id that doesn't belong to this user, a new event is created
        # with a fresh backend-generated UUID (not the provided one).
        unknown_id = str(uuid.uuid4())
        upsert = {**BASE_EVENT, "id": unknown_id}
        resp = client.post("/events/sync", json={"upserts": [upsert]}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["created"]) == 1
        assert body["created"][0]["id"] != unknown_id


class TestSyncUpdate:
    def test_update_existing_event(self, client, auth_headers):
        event = _create_event(client, auth_headers)
        upsert = {**BASE_EVENT, "id": event["id"], "title": "Updated via sync"}
        resp = client.post("/events/sync", json={"upserts": [upsert]}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["updated"]) == 1
        assert len(body["created"]) == 0
        assert body["updated"][0]["title"] == "Updated via sync"

    def test_update_reflected_in_get(self, client, auth_headers):
        event = _create_event(client, auth_headers)
        upsert = {**BASE_EVENT, "id": event["id"], "location": "New location"}
        client.post("/events/sync", json={"upserts": [upsert]}, headers=auth_headers)
        get_resp = client.get(f"/events/{event['id']}", headers=auth_headers)
        assert get_resp.json()["location"] == "New location"

    def test_mixed_create_and_update(self, client, auth_headers):
        existing = _create_event(client, auth_headers)
        upserts = [
            {**BASE_EVENT, "id": existing["id"], "title": "Updated"},
            {**BASE_EVENT, "title": "Brand new"},
        ]
        resp = client.post("/events/sync", json={"upserts": upserts}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["updated"]) == 1
        assert len(body["created"]) == 1


class TestSyncDelete:
    def test_delete_existing_event(self, client, auth_headers):
        event = _create_event(client, auth_headers)
        resp = client.post("/events/sync", json={"upserts": [], "deletes": [event["id"]]}, headers=auth_headers)
        assert resp.status_code == 200
        assert event["id"] in resp.json()["deleted"]

        get_resp = client.get(f"/events/{event['id']}", headers=auth_headers)
        assert get_resp.status_code == 404

    def test_delete_nonexistent_is_silent(self, client, auth_headers):
        fake_id = str(uuid.uuid4())
        resp = client.post("/events/sync", json={"deletes": [fake_id]}, headers=auth_headers)
        assert resp.status_code == 200
        assert fake_id not in resp.json()["deleted"]

    def test_delete_multiple(self, client, auth_headers):
        e1 = _create_event(client, auth_headers)
        e2 = _create_event(client, auth_headers)
        resp = client.post(
            "/events/sync",
            json={"deletes": [e1["id"], e2["id"]]},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert len(resp.json()["deleted"]) == 2


class TestSyncMixed:
    def test_full_batch(self, client, auth_headers):
        existing = _create_event(client, auth_headers)
        to_delete = _create_event(client, auth_headers)

        resp = client.post(
            "/events/sync",
            json={
                "upserts": [
                    {**BASE_EVENT, "title": "New from sync"},
                    {**BASE_EVENT, "id": existing["id"], "title": "Updated from sync"},
                ],
                "deletes": [to_delete["id"]],
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["created"]) == 1
        assert len(body["updated"]) == 1
        assert len(body["deleted"]) == 1

    def test_empty_request(self, client, auth_headers):
        resp = client.post("/events/sync", json={"upserts": [], "deletes": []}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["created"] == []
        assert body["updated"] == []
        assert body["deleted"] == []


class TestSyncValidation:
    def test_end_before_start_returns_422(self, client, auth_headers):
        bad_upsert = {**BASE_EVENT, "end_at": "2026-05-01T09:00:00"}
        resp = client.post("/events/sync", json={"upserts": [bad_upsert]}, headers=auth_headers)
        assert resp.status_code == 422

    def test_missing_title_returns_422(self, client, auth_headers):
        bad_upsert = {k: v for k, v in BASE_EVENT.items() if k != "title"}
        resp = client.post("/events/sync", json={"upserts": [bad_upsert]}, headers=auth_headers)
        assert resp.status_code == 422

    def test_too_many_upserts_returns_422(self, client, auth_headers):
        upserts = [BASE_EVENT] * 501
        resp = client.post("/events/sync", json={"upserts": upserts}, headers=auth_headers)
        assert resp.status_code == 422

    def test_too_many_deletes_returns_422(self, client, auth_headers):
        deletes = [str(uuid.uuid4()) for _ in range(501)]
        resp = client.post("/events/sync", json={"deletes": deletes}, headers=auth_headers)
        assert resp.status_code == 422

    def test_no_auth_returns_401(self, client):
        resp = client.post("/events/sync", json={"upserts": [BASE_EVENT]})
        assert resp.status_code == 401


class TestSyncIsolation:
    def test_cannot_update_another_users_event(self, client, auth_headers):
        event = _create_event(client, auth_headers)

        email2 = f"sync_test_{uuid.uuid4().hex[:8]}@example.com"
        client.post("/auth/register", json={"email": email2, "password": "StrongPass1!"})
        token2 = client.post("/auth/login", json={"email": email2, "password": "StrongPass1!"}).json()["access_token"]
        headers2 = {"Authorization": f"Bearer {token2}"}

        upsert = {**BASE_EVENT, "id": event["id"], "title": "Hijacked"}
        resp = client.post("/events/sync", json={"upserts": [upsert]}, headers=headers2)
        assert resp.status_code == 200
        # Event id is unknown to user2, so it gets created as new (not updating user1's event)
        body = resp.json()
        assert len(body["created"]) == 1

        original = client.get(f"/events/{event['id']}", headers=auth_headers)
        assert original.json()["title"] != "Hijacked"

    def test_cannot_delete_another_users_event(self, client, auth_headers):
        event = _create_event(client, auth_headers)

        email2 = f"sync_test_{uuid.uuid4().hex[:8]}@example.com"
        client.post("/auth/register", json={"email": email2, "password": "StrongPass1!"})
        token2 = client.post("/auth/login", json={"email": email2, "password": "StrongPass1!"}).json()["access_token"]
        headers2 = {"Authorization": f"Bearer {token2}"}

        resp = client.post("/events/sync", json={"deletes": [event["id"]]}, headers=headers2)
        assert resp.status_code == 200
        assert event["id"] not in resp.json()["deleted"]

        original = client.get(f"/events/{event['id']}", headers=auth_headers)
        assert original.status_code == 200
