import uuid
import pytest
import httpx

BASE_URL = "http://localhost:8000/api/v1"

EVENT = {
    "title": "Test event",
    "start_at": "2026-06-01T10:00:00+00:00",
    "end_at": "2026-06-01T11:00:00+00:00",
    "all_day": False,
    "type": "event",
    "is_fixed": False,
    "source": "user",
}

AI_EVENT = {**EVENT, "source": "ai", "start_at": "2026-06-02T10:00:00+00:00", "end_at": "2026-06-02T11:00:00+00:00"}

REMINDER = {
    "title": "Test reminder",
    "start_at": "2026-06-03T09:00:00+00:00",
    "all_day": False,
    "type": "reminder",
    "is_fixed": False,
    "source": "user",
}


def make_user(client: httpx.Client) -> dict:
    email = f"ach_{uuid.uuid4().hex[:10]}@test.com"
    password = "TestPass1!"
    client.post("/auth/register", json={"email": email, "password": password})
    resp = client.post("/auth/login", json={"email": email, "password": password})
    token = resp.json()["access_token"]
    return {"headers": {"Authorization": f"Bearer {token}"}}


@pytest.fixture(scope="module")
def client():
    with httpx.Client(base_url=BASE_URL, timeout=30, follow_redirects=True) as c:
        yield c


def get_group(data: dict, group_code: str) -> dict | None:
    return next((g for g in data["groups"] if g["group_code"] == group_code), None)


def get_level(group: dict, level: int) -> dict | None:
    return next((lv for lv in group["levels"] if lv["level"] == level), None)


class TestAchievementsStructure:
    """Проверяем корректность формата ответа."""

    def test_returns_groups(self, client):
        user = make_user(client)
        resp = client.get("/achievements/", headers=user["headers"])
        assert resp.status_code == 200
        data = resp.json()
        assert "groups" in data
        assert isinstance(data["groups"], list)

    def test_fresh_user_all_counters_zero(self, client):
        user = make_user(client)
        resp = client.get("/achievements/", headers=user["headers"])
        data = resp.json()
        for group in data["groups"]:
            assert group["current_value"] == 0

    def test_levels_ordered_ascending(self, client):
        user = make_user(client)
        resp = client.get("/achievements/", headers=user["headers"])
        for group in resp.json()["groups"]:
            targets = [l["target_value"] for l in group["levels"]]
            assert targets == sorted(targets)

    def test_fresh_user_no_unlocked_achievements(self, client):
        user = make_user(client)
        resp = client.get("/achievements/", headers=user["headers"])
        for group in resp.json()["groups"]:
            for level in group["levels"]:
                assert level["unlocked"] is False
                assert level["earned_at"] is None

    def test_requires_auth(self, client):
        resp = client.get("/achievements/")
        assert resp.status_code == 401


class TestCounterIncrements:
    """Проверяем что счётчики правильно обновляются."""

    def test_user_event_increments_total_events(self, client):
        user = make_user(client)
        client.post("/events/", json=EVENT, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] == 1

    def test_ai_event_increments_total_events(self, client):
        """AI-событие должно учитываться в total_events."""
        user = make_user(client)
        client.post("/events/", json=AI_EVENT, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] == 1

    def test_ai_event_increments_ai_counter(self, client):
        user = make_user(client)
        client.post("/events/", json=AI_EVENT, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "ai_assisted")
        assert group["current_value"] == 1

    def test_user_event_does_not_increment_ai_counter(self, client):
        user = make_user(client)
        client.post("/events/", json=EVENT, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "ai_assisted")
        assert group["current_value"] == 0

    def test_reminder_increments_reminder_counter(self, client):
        user = make_user(client)
        client.post("/events/", json=REMINDER, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "reminders")
        assert group["current_value"] == 1

    def test_reminder_also_increments_total_events(self, client):
        user = make_user(client)
        client.post("/events/", json=REMINDER, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] == 1

    def test_multiple_events_accumulate(self, client):
        user = make_user(client)
        for i in range(3):
            ev = {**EVENT, "start_at": f"2026-06-{10 + i:02d}T10:00:00+00:00",
                  "end_at": f"2026-06-{10 + i:02d}T11:00:00+00:00"}
            client.post("/events/", json=ev, headers=user["headers"])
        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] == 3


class TestCounterDecrements:
    """Проверяем что удаление событий корректно обновляет счётчики."""

    def test_delete_decrements_total_events(self, client):
        user = make_user(client)
        r = client.post("/events/", json=EVENT, headers=user["headers"])
        event_id = r.json()["id"]

        client.delete(f"/events/{event_id}", headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] == 0

    def test_delete_ai_event_decrements_ai_counter(self, client):
        user = make_user(client)
        r = client.post("/events/", json=AI_EVENT, headers=user["headers"])
        event_id = r.json()["id"]

        client.delete(f"/events/{event_id}", headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "ai_assisted")
        assert group["current_value"] == 0

    def test_counter_never_goes_negative(self, client):
        """Удаление при нулевом счётчике не должно давать отрицательное значение."""
        user = make_user(client)
        r = client.post("/events/", json=EVENT, headers=user["headers"])
        event_id = r.json()["id"]
        client.delete(f"/events/{event_id}", headers=user["headers"])
        # Второе удаление того же события — 404, счётчик не должен уйти в минус
        client.delete(f"/events/{event_id}", headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] >= 0


class TestActiveDays:
    """Проверяем логику подсчёта уникальных дней."""

    def test_two_events_same_day_count_as_one(self, client):
        user = make_user(client)
        ev1 = {**EVENT, "start_at": "2026-07-01T09:00:00+00:00", "end_at": "2026-07-01T10:00:00+00:00"}
        ev2 = {**EVENT, "start_at": "2026-07-01T15:00:00+00:00", "end_at": "2026-07-01T16:00:00+00:00"}
        client.post("/events/", json=ev1, headers=user["headers"])
        client.post("/events/", json=ev2, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "active_days")
        assert group["current_value"] == 1

    def test_events_on_different_days_count_separately(self, client):
        user = make_user(client)
        for day in range(3):
            ev = {**EVENT, "start_at": f"2026-07-{10 + day:02d}T10:00:00+00:00",
                  "end_at": f"2026-07-{10 + day:02d}T11:00:00+00:00"}
            client.post("/events/", json=ev, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "active_days")
        assert group["current_value"] == 3

    def test_delete_last_event_on_day_reduces_active_days(self, client):
        user = make_user(client)
        ev = {**EVENT, "start_at": "2026-08-01T10:00:00+00:00", "end_at": "2026-08-01T11:00:00+00:00"}
        r = client.post("/events/", json=ev, headers=user["headers"])
        event_id = r.json()["id"]

        client.delete(f"/events/{event_id}", headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "active_days")
        assert group["current_value"] == 0


class TestAchievementUnlocking:
    """Проверяем логику выдачи достижений."""

    def test_first_event_unlocks_level_1(self, client):
        user = make_user(client)
        client.post("/events/", json=EVENT, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        level1 = get_level(group, 1)
        assert level1["unlocked"] is True
        assert level1["earned_at"] is not None

    def test_level_2_not_unlocked_after_one_event(self, client):
        user = make_user(client)
        client.post("/events/", json=EVENT, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        level2 = get_level(group, 2)
        assert level2["unlocked"] is False

    def test_achievement_not_awarded_twice(self, client):
        """Создание ещё одного события не должно дублировать первый уровень."""
        user = make_user(client)
        ev1 = {**EVENT, "start_at": "2026-09-01T10:00:00+00:00", "end_at": "2026-09-01T11:00:00+00:00"}
        ev2 = {**EVENT, "start_at": "2026-09-02T10:00:00+00:00", "end_at": "2026-09-02T11:00:00+00:00"}
        client.post("/events/", json=ev1, headers=user["headers"])
        client.post("/events/", json=ev2, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "events_created")
        unlocked = [lv for lv in group["levels"] if lv["unlocked"]]
        level1_entries = [lv for lv in unlocked if lv["level"] == 1]
        assert len(level1_entries) == 1

    def test_reminder_unlocks_reminder_achievement(self, client):
        user = make_user(client)
        client.post("/events/", json=REMINDER, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "reminders")
        level1 = get_level(group, 1)
        assert level1["unlocked"] is True

    def test_ai_event_unlocks_ai_achievement(self, client):
        user = make_user(client)
        client.post("/events/", json=AI_EVENT, headers=user["headers"])

        resp = client.get("/achievements/", headers=user["headers"])
        group = get_group(resp.json(), "ai_assisted")
        level1 = get_level(group, 1)
        assert level1["unlocked"] is True


class TestUserIsolation:
    """Достижения и счётчики не должны пересекаться между пользователями."""

    def test_events_of_user_a_not_visible_to_user_b(self, client):
        user_a = make_user(client)
        user_b = make_user(client)

        client.post("/events/", json=EVENT, headers=user_a["headers"])

        resp = client.get("/achievements/", headers=user_b["headers"])
        group = get_group(resp.json(), "events_created")
        assert group["current_value"] == 0

    def test_achievements_of_user_a_not_visible_to_user_b(self, client):
        user_a = make_user(client)
        user_b = make_user(client)

        client.post("/events/", json=EVENT, headers=user_a["headers"])

        resp = client.get("/achievements/", headers=user_b["headers"])
        for group in resp.json()["groups"]:
            for level in group["levels"]:
                assert level["unlocked"] is False
