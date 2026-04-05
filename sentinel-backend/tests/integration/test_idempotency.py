import uuid
import pytest
import httpx

BASE_URL = "http://localhost:8000/api/v1"

EVENT_PAYLOAD = {
    "title": "Idempotency test event",
    "start_at": "2026-05-01T10:00:00",
    "end_at": "2026-05-01T11:00:00",
    "all_day": False,
    "type": "event",
    "is_fixed": False,
    "source": "user",
}


def make_user(client: httpx.Client) -> dict:
    email = f"idem_{uuid.uuid4().hex[:8]}@example.com"
    password = "StrongPass1!"
    r = client.post("/auth/register", json={"email": email, "password": password})
    assert r.status_code == 201, r.text
    r2 = client.post("/auth/login", json={"email": email, "password": password})
    assert r2.status_code == 200, r2.text
    token = r2.json()["access_token"]
    return {"headers": {"Authorization": f"Bearer {token}"}}


@pytest.fixture(scope="module")
def client():
    with httpx.Client(base_url=BASE_URL, timeout=30, follow_redirects=True) as c:
        yield c


class TestIdempotencyKey:
    def test_without_key_creates_duplicate(self, client):
        user = make_user(client)
        r1 = client.post("/events/", json=EVENT_PAYLOAD, headers=user["headers"])
        r2 = client.post("/events/", json=EVENT_PAYLOAD, headers=user["headers"])
        assert r1.status_code == 201
        assert r2.status_code == 201
        # без ключа — два разных события
        assert r1.json()["id"] != r2.json()["id"]

    def test_same_key_returns_same_event(self, client):
        user = make_user(client)
        key = str(uuid.uuid4())
        headers = {**user["headers"], "X-Idempotency-Key": key}

        r1 = client.post("/events/", json=EVENT_PAYLOAD, headers=headers)
        r2 = client.post("/events/", json=EVENT_PAYLOAD, headers=headers)

        assert r1.status_code == 201
        assert r2.status_code == 200
        assert r1.json()["id"] == r2.json()["id"]

    def test_different_keys_create_different_events(self, client):
        user = make_user(client)
        h1 = {**user["headers"], "X-Idempotency-Key": str(uuid.uuid4())}
        h2 = {**user["headers"], "X-Idempotency-Key": str(uuid.uuid4())}

        r1 = client.post("/events/", json=EVENT_PAYLOAD, headers=h1)
        r2 = client.post("/events/", json=EVENT_PAYLOAD, headers=h2)

        assert r1.status_code == 201
        assert r2.status_code == 201
        assert r1.json()["id"] != r2.json()["id"]

    def test_same_key_different_users_create_different_events(self, client):
        user1 = make_user(client)
        user2 = make_user(client)
        key = str(uuid.uuid4())

        h1 = {**user1["headers"], "X-Idempotency-Key": key}
        h2 = {**user2["headers"], "X-Idempotency-Key": key}

        r1 = client.post("/events/", json=EVENT_PAYLOAD, headers=h1)
        r2 = client.post("/events/", json=EVENT_PAYLOAD, headers=h2)

        assert r1.status_code == 201
        assert r2.status_code == 201
        # один и тот же ключ, но разные пользователи — должно быть разные события
        assert r1.json()["id"] != r2.json()["id"]

    def test_repeated_request_returns_original_data(self, client):
        user = make_user(client)
        key = str(uuid.uuid4())
        headers = {**user["headers"], "X-Idempotency-Key": key}

        payload = {**EVENT_PAYLOAD, "title": "Unique title for idempotency check"}
        r1 = client.post("/events/", json=payload, headers=headers)
        r2 = client.post("/events/", json=payload, headers=headers)

        assert r1.json()["title"] == r2.json()["title"]
        assert r1.json()["id"] == r2.json()["id"]

    def test_key_isolation_after_event_deleted(self, client):
        """После удаления события idempotency-запись тоже удаляется (CASCADE).
        Повторный запрос с тем же ключом создаёт новое событие."""
        user = make_user(client)
        key = str(uuid.uuid4())
        headers = {**user["headers"], "X-Idempotency-Key": key}

        r1 = client.post("/events/", json=EVENT_PAYLOAD, headers=headers)
        assert r1.status_code == 201
        event_id = r1.json()["id"]

        del_resp = client.delete(f"/events/{event_id}", headers=user["headers"])
        assert del_resp.status_code == 204

        r2 = client.post("/events/", json=EVENT_PAYLOAD, headers=headers)
        assert r2.status_code == 201
        # idempotency-запись удалилась вместе с событием — создаётся новое
        assert r2.json()["id"] != event_id
