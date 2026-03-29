import pytest


@pytest.fixture(scope="module")
def chat(client, auth_headers):
    resp = client.post("/chats", json={"title": "Test chat"}, headers=auth_headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


class TestCreateChat:
    def test_create_chat_success(self, client, auth_headers):
        resp = client.post("/chats", json={"title": "My Calendar"}, headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["title"] == "My Calendar"
        assert "id" in body
        assert "user_id" in body

    def test_create_chat_empty_title(self, client, auth_headers):
        resp = client.post("/chats", json={"title": ""}, headers=auth_headers)
        assert resp.status_code == 422

    def test_create_chat_no_auth(self, client):
        resp = client.post("/chats", json={"title": "X"})
        assert resp.status_code == 401


class TestListChats:
    def test_list_chats(self, client, auth_headers, chat):
        resp = client.get("/chats", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "items" in body
        assert "total" in body
        assert body["total"] >= 1

    def test_list_chats_no_auth(self, client):
        resp = client.get("/chats")
        assert resp.status_code == 401


class TestMessages:
    def test_get_messages_empty(self, client, auth_headers, chat):
        chat_id = chat["id"]
        resp = client.get(f"/chats/{chat_id}/messages", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["items"] == []
        assert body["has_more"] is False

    def test_send_user_message_triggers_ai(self, client, auth_headers, chat):
        chat_id = chat["id"]
        resp = client.post(
            f"/chats/{chat_id}/messages",
            json={"role": "user", "content_text": "Привет! Что ты умеешь?"},
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable (503) — check LLM_API_KEY in .env")
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["role"] == "assistant"
        assert body["chat_id"] == chat_id
        assert body["content_text"] is not None or body["content_structured"] is not None

    def test_message_history_populated(self, client, auth_headers, chat):
        chat_id = chat["id"]
        resp = client.get(f"/chats/{chat_id}/messages", headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()["items"]) >= 1

    def test_pagination_limit(self, client, auth_headers, chat):
        chat_id = chat["id"]
        resp = client.get(
            f"/chats/{chat_id}/messages",
            params={"limit": 1},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert len(resp.json()["items"]) <= 1

    def test_send_message_to_nonexistent_chat(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        resp = client.post(
            f"/chats/{fake_id}/messages",
            json={"role": "user", "content_text": "hello"},
            headers=auth_headers,
        )
        assert resp.status_code == 404

    def test_send_message_no_auth(self, client, chat):
        chat_id = chat["id"]
        resp = client.post(
            f"/chats/{chat_id}/messages",
            json={"role": "user", "content_text": "hello"},
        )
        assert resp.status_code == 401


class TestLLMToolCalling:
    def test_ai_suggests_event_creation(self, client, auth_headers):
        chat_resp = client.post(
            "/chats", json={"title": "Tool call test"}, headers=auth_headers
        )
        chat_id = chat_resp.json()["id"]

        resp = client.post(
            f"/chats/{chat_id}/messages",
            json={
                "role": "user",
                "content_text": (
                    "Создай встречу 'Тест инструментов' на 15 апреля 2026 года с 14:00 до 15:00."
                ),
            },
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable (503)")
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["role"] == "assistant"

        has_text = body.get("content_text") is not None
        has_actions = (
            body.get("content_structured") is not None
            and body["content_structured"].get("type") == "event_actions"
        )
        assert has_text or has_actions, f"Expected text or actions in response, got: {body}"

    def test_apply_accepted_actions(self, client, auth_headers):
        chat_resp = client.post(
            "/chats", json={"title": "Apply actions test"}, headers=auth_headers
        )
        chat_id = chat_resp.json()["id"]

        msg_resp = client.post(
            f"/chats/{chat_id}/messages",
            json={
                "role": "user",
                "content_text": (
                    "Добавь событие 'Демо для клиента' на 20 апреля 2026 года с 10:00 до 11:00."
                ),
            },
            headers=auth_headers,
            timeout=60,
        )
        if msg_resp.status_code == 503:
            pytest.skip("LLM service unavailable (503)")
        assert msg_resp.status_code == 201, msg_resp.text
        ai_message = msg_resp.json()

        structured = ai_message.get("content_structured")
        if structured is None or structured.get("type") != "event_actions":
            pytest.skip("AI did not propose event actions for this prompt (non-deterministic)")

        actions = structured["actions"]
        assert len(actions) > 0

        message_id = ai_message["id"]
        apply_resp = client.post(
            f"/chats/{chat_id}/messages/{message_id}/apply",
            json={"accepted_indices": list(range(len(actions)))},
            headers=auth_headers,
        )
        assert apply_resp.status_code == 200, apply_resp.text
        applied_actions = apply_resp.json()["content_structured"]["actions"]
        assert all(a["status"] == "accepted" for a in applied_actions)

    def test_apply_rejected_actions(self, client, auth_headers):
        chat_resp = client.post(
            "/chats", json={"title": "Reject actions test"}, headers=auth_headers
        )
        chat_id = chat_resp.json()["id"]

        msg_resp = client.post(
            f"/chats/{chat_id}/messages",
            json={
                "role": "user",
                "content_text": "Создай событие 'Отклоняемая встреча' на 25 апреля 2026 в 09:00.",
            },
            headers=auth_headers,
            timeout=60,
        )
        if msg_resp.status_code == 503:
            pytest.skip("LLM service unavailable (503)")
        assert msg_resp.status_code == 201
        ai_message = msg_resp.json()

        structured = ai_message.get("content_structured")
        if structured is None or structured.get("type") != "event_actions":
            pytest.skip("AI did not propose event actions (non-deterministic)")

        message_id = ai_message["id"]
        apply_resp = client.post(
            f"/chats/{chat_id}/messages/{message_id}/apply",
            json={"accepted_indices": []},
            headers=auth_headers,
        )
        assert apply_resp.status_code == 200
        applied_actions = apply_resp.json()["content_structured"]["actions"]
        assert all(a["status"] == "rejected" for a in applied_actions)

    def test_ai_reads_calendar_via_search(self, client, auth_headers):
        chat_resp = client.post(
            "/chats", json={"title": "Calendar read test"}, headers=auth_headers
        )
        chat_id = chat_resp.json()["id"]

        resp = client.post(
            f"/chats/{chat_id}/messages",
            json={
                "role": "user",
                "content_text": "Какие у меня события в апреле 2026?",
            },
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable (503)")
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["role"] == "assistant"
        assert body["content_text"] is not None
