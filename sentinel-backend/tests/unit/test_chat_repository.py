import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.schemas.chat import ChatCreate, ChatMessageCreate
from app.infrastructure.database.repositories.chat_repository import ChatMessageRepository, ChatRepository


def _make_message(
    role: str,
    content_text: str | None,
    content_structured: dict | None = None,
    created_at: datetime | None = None,
) -> MagicMock:
    msg = MagicMock()
    msg.id = uuid.uuid4()
    msg.role = role
    msg.content_text = content_text
    msg.content_structured = content_structured
    msg.created_at = created_at or datetime.now(timezone.utc)
    return msg


def _repo_with_messages(messages: list) -> ChatMessageRepository:
    """Build a ChatMessageRepository whose execute() returns the given messages."""
    scalars_mock = MagicMock()
    scalars_mock.all.return_value = list(reversed(messages))

    result_mock = MagicMock()
    result_mock.scalars.return_value = scalars_mock

    db = AsyncMock()
    db.execute = AsyncMock(return_value=result_mock)
    return ChatMessageRepository(db)


class TestGetRecentForLlmTextMessages:
    @pytest.mark.asyncio
    async def test_plain_user_message_formatted_correctly(self):
        messages = [_make_message("user", "Hello")]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert len(history) == 1
        assert history[0] == {"role": "user", "content": "Hello"}

    @pytest.mark.asyncio
    async def test_assistant_message_formatted_correctly(self):
        messages = [_make_message("assistant", "How can I help?")]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert history[0] == {"role": "assistant", "content": "How can I help?"}

    @pytest.mark.asyncio
    async def test_empty_content_text_becomes_empty_string(self):
        messages = [_make_message("assistant", None)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert history[0]["content"] == ""

    @pytest.mark.asyncio
    async def test_messages_returned_oldest_first(self):
        t1 = datetime(2026, 4, 1, 10, 0, tzinfo=timezone.utc)
        t2 = datetime(2026, 4, 1, 11, 0, tzinfo=timezone.utc)
        messages = [
            _make_message("user", "first", created_at=t1),
            _make_message("assistant", "second", created_at=t2),
        ]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert history[0]["content"] == "first"
        assert history[1]["content"] == "second"


class TestGetRecentForLlmImageMessages:
    @pytest.mark.asyncio
    async def test_image_message_produces_multimodal_content_list(self):
        structured = {
            "type": "image_message",
            "images": [{"url": "https://example.com/img.jpg", "filename": "img.jpg", "mime_type": "image/jpeg"}],
        }
        messages = [_make_message("user", "Look at this", content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert len(history) == 1
        content = history[0]["content"]
        assert isinstance(content, list)

    @pytest.mark.asyncio
    async def test_image_message_includes_text_block(self):
        structured = {
            "type": "image_message",
            "images": [{"url": "https://example.com/a.png", "filename": "a.png", "mime_type": "image/png"}],
        }
        messages = [_make_message("user", "Describe this image", content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        content = history[0]["content"]
        text_blocks = [b for b in content if b.get("type") == "text"]
        assert len(text_blocks) == 1
        assert text_blocks[0]["text"] == "Describe this image"

    @pytest.mark.asyncio
    async def test_image_message_includes_image_url_block(self):
        structured = {
            "type": "image_message",
            "images": [{"url": "https://example.com/photo.jpg", "filename": "photo.jpg", "mime_type": "image/jpeg"}],
        }
        messages = [_make_message("user", "What's here?", content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        content = history[0]["content"]
        image_blocks = [b for b in content if b.get("type") == "image_url"]
        assert len(image_blocks) == 1
        assert image_blocks[0]["image_url"]["url"] == "https://example.com/photo.jpg"

    @pytest.mark.asyncio
    async def test_image_message_multiple_images_all_included(self):
        structured = {
            "type": "image_message",
            "images": [
                {"url": "https://example.com/a.jpg", "filename": "a.jpg", "mime_type": "image/jpeg"},
                {"url": "https://example.com/b.jpg", "filename": "b.jpg", "mime_type": "image/jpeg"},
            ],
        }
        messages = [_make_message("user", "Compare", content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        content = history[0]["content"]
        image_blocks = [b for b in content if b.get("type") == "image_url"]
        assert len(image_blocks) == 2

    @pytest.mark.asyncio
    async def test_image_message_no_text_omits_text_block(self):
        structured = {
            "type": "image_message",
            "images": [{"url": "https://example.com/a.jpg", "filename": "a.jpg", "mime_type": "image/jpeg"}],
        }
        messages = [_make_message("user", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        content = history[0]["content"]
        text_blocks = [b for b in content if b.get("type") == "text"]
        assert len(text_blocks) == 0

    @pytest.mark.asyncio
    async def test_event_actions_with_empty_list_returns_text(self):
        structured = {"type": "event_actions", "actions": []}
        messages = [_make_message("assistant", "No actions", content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert history[0]["content"] == "No actions"

    @pytest.mark.asyncio
    async def test_event_actions_create_accepted(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "create", "status": "accepted", "payload": {"title": "Meeting", "start_at": "2026-06-01T10:00"}}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "Meeting" in history[0]["content"]
        assert "saved" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_create_rejected(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "create", "status": "rejected", "payload": {"title": "Standup", "start_at": "2026-06-01T09:00"}}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "Standup" in history[0]["content"]
        assert "declined" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_create_pending(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "create", "status": "pending", "payload": {"title": "Lunch", "start_at": "2026-06-01T12:00"}}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "awaiting" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_update_accepted(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "update", "status": "accepted", "event_id": "ev-42"}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "ev-42" in history[0]["content"]
        assert "updated" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_update_rejected(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "update", "status": "rejected", "event_id": "ev-7"}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "ev-7" in history[0]["content"]
        assert "declined" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_update_pending(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "update", "status": "pending", "event_id": "ev-3"}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "awaiting" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_delete_accepted(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "delete", "status": "accepted", "event_id": "ev-99"}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "ev-99" in history[0]["content"]
        assert "deleted" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_delete_rejected(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "delete", "status": "rejected", "event_id": "ev-11"}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "declined" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_event_actions_delete_pending(self):
        structured = {
            "type": "event_actions",
            "actions": [{"action": "delete", "status": "pending", "event_id": "ev-5"}],
        }
        messages = [_make_message("assistant", None, content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert "awaiting" in history[0]["content"]

    @pytest.mark.asyncio
    async def test_mixed_messages_preserve_order_and_format(self):
        t1 = datetime(2026, 4, 1, 10, 0, tzinfo=timezone.utc)
        t2 = datetime(2026, 4, 1, 10, 1, tzinfo=timezone.utc)
        t3 = datetime(2026, 4, 1, 10, 2, tzinfo=timezone.utc)
        structured = {
            "type": "image_message",
            "images": [{"url": "https://example.com/x.jpg", "filename": "x.jpg", "mime_type": "image/jpeg"}],
        }
        messages = [
            _make_message("user", "text only", created_at=t1),
            _make_message("user", "with image", content_structured=structured, created_at=t2),
            _make_message("assistant", "reply", created_at=t3),
        ]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert len(history) == 3
        assert history[0]["content"] == "text only"
        assert isinstance(history[1]["content"], list)
        assert history[2]["content"] == "reply"


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.delete = AsyncMock()
    return db


def _make_chat(**kwargs) -> MagicMock:
    c = MagicMock()
    c.id = kwargs.get("id", uuid.uuid4())
    c.user_id = kwargs.get("user_id", uuid.uuid4())
    c.title = kwargs.get("title", "Test Chat")
    c.last_message_at = kwargs.get("last_message_at", None)
    return c


def _result_with_list(items: list) -> MagicMock:
    result = MagicMock()
    scalars = MagicMock()
    scalars.all.return_value = items
    result.scalars.return_value = scalars
    return result


def _result_with_scalar(value) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


class TestChatRepositoryGetUserChats:
    @pytest.mark.asyncio
    async def test_returns_chats(self):
        db = _mock_db()
        chats = [_make_chat(), _make_chat()]
        db.execute.return_value = _result_with_list(chats)
        repo = ChatRepository(db)

        result = await repo.get_user_chats(uuid.uuid4())

        assert result == chats

    @pytest.mark.asyncio
    async def test_returns_empty_list(self):
        db = _mock_db()
        db.execute.return_value = _result_with_list([])
        repo = ChatRepository(db)

        result = await repo.get_user_chats(uuid.uuid4())

        assert result == []


class TestChatRepositoryGetById:
    @pytest.mark.asyncio
    async def test_returns_chat_when_found(self):
        db = _mock_db()
        chat = _make_chat()
        db.execute.return_value = _result_with_scalar(chat)
        repo = ChatRepository(db)

        result = await repo.get_by_id(chat.id, chat.user_id)

        assert result == chat

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_scalar(None)
        repo = ChatRepository(db)

        result = await repo.get_by_id(uuid.uuid4(), uuid.uuid4())

        assert result is None


class TestChatRepositoryCreate:
    @pytest.mark.asyncio
    async def test_adds_and_commits(self):
        db = _mock_db()
        repo = ChatRepository(db)

        await repo.create(uuid.uuid4(), ChatCreate(title="New Chat"))

        db.add.assert_called_once()
        db.commit.assert_awaited_once()
        db.refresh.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_chat(self):
        db = _mock_db()
        repo = ChatRepository(db)

        result = await repo.create(uuid.uuid4(), ChatCreate(title="Chat"))

        assert result is not None


class TestChatRepositoryDelete:
    @pytest.mark.asyncio
    async def test_returns_true_and_deletes(self):
        db = _mock_db()
        chat = _make_chat()
        db.execute.return_value = _result_with_scalar(chat)
        repo = ChatRepository(db)

        result = await repo.delete(chat.id, chat.user_id)

        assert result is True
        db.delete.assert_awaited_once_with(chat)
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_false_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_scalar(None)
        repo = ChatRepository(db)

        result = await repo.delete(uuid.uuid4(), uuid.uuid4())

        assert result is False
        db.delete.assert_not_awaited()


def _make_msg_mock(**kwargs) -> MagicMock:
    m = MagicMock()
    m.id = kwargs.get("id", uuid.uuid4())
    m.chat_id = kwargs.get("chat_id", uuid.uuid4())
    m.role = kwargs.get("role", "user")
    m.content_text = kwargs.get("content_text", "Hello")
    m.content_structured = kwargs.get("content_structured", None)
    m.created_at = kwargs.get("created_at", datetime.now(timezone.utc))
    return m


class TestChatMessageRepositoryGetMessages:
    @pytest.mark.asyncio
    async def test_returns_messages_chronological(self):
        db = _mock_db()
        m1 = _make_msg_mock()
        m2 = _make_msg_mock()
        db.execute.return_value = _result_with_list([m2, m1])
        repo = ChatMessageRepository(db)

        messages, has_more = await repo.get_messages(uuid.uuid4(), limit=10)

        assert messages == [m1, m2]
        assert has_more is False

    @pytest.mark.asyncio
    async def test_has_more_when_over_limit(self):
        db = _mock_db()
        msgs = [_make_msg_mock() for _ in range(6)]
        db.execute.return_value = _result_with_list(msgs)
        repo = ChatMessageRepository(db)

        messages, has_more = await repo.get_messages(uuid.uuid4(), limit=5)

        assert has_more is True
        assert len(messages) == 5

    @pytest.mark.asyncio
    async def test_with_before_cursor_found(self):
        db = _mock_db()
        ref_ts = datetime.now(timezone.utc)
        ref_result = MagicMock()
        ref_result.scalar_one_or_none.return_value = ref_ts
        msgs_result = _result_with_list([_make_msg_mock()])
        db.execute.side_effect = [ref_result, msgs_result]
        repo = ChatMessageRepository(db)

        messages, _ = await repo.get_messages(uuid.uuid4(), limit=10, before=uuid.uuid4())

        assert db.execute.await_count == 2

    @pytest.mark.asyncio
    async def test_with_before_cursor_not_found_skips_filter(self):
        db = _mock_db()
        ref_result = MagicMock()
        ref_result.scalar_one_or_none.return_value = None
        msgs_result = _result_with_list([])
        db.execute.side_effect = [ref_result, msgs_result]
        repo = ChatMessageRepository(db)

        messages, _ = await repo.get_messages(uuid.uuid4(), limit=10, before=uuid.uuid4())

        assert messages == []


class TestChatMessageRepositoryGetById:
    @pytest.mark.asyncio
    async def test_returns_message_when_found(self):
        db = _mock_db()
        msg = _make_msg_mock()
        db.execute.return_value = _result_with_scalar(msg)
        repo = ChatMessageRepository(db)

        result = await repo.get_by_id(msg.id, msg.chat_id)

        assert result == msg

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_scalar(None)
        repo = ChatMessageRepository(db)

        result = await repo.get_by_id(uuid.uuid4(), uuid.uuid4())

        assert result is None


class TestChatMessageRepositoryCreate:
    @pytest.mark.asyncio
    async def test_adds_and_commits(self):
        db = _mock_db()
        chat = _make_chat()
        db.execute.return_value = _result_with_scalar(chat)
        repo = ChatMessageRepository(db)

        data = ChatMessageCreate(role="user", content_text="Hello")
        await repo.create(chat.id, data)

        db.add.assert_called_once()
        db.commit.assert_awaited_once()
        db.refresh.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_updates_chat_last_message_at(self):
        db = _mock_db()
        chat = _make_chat()
        db.execute.return_value = _result_with_scalar(chat)
        repo = ChatMessageRepository(db)

        data = ChatMessageCreate(role="user", content_text="Hi")
        await repo.create(chat.id, data)

        assert chat.last_message_at is not None

    @pytest.mark.asyncio
    async def test_chat_not_found_still_commits(self):
        db = _mock_db()
        db.execute.return_value = _result_with_scalar(None)
        repo = ChatMessageRepository(db)

        data = ChatMessageCreate(role="assistant", content_text="Reply")
        await repo.create(uuid.uuid4(), data)

        db.commit.assert_awaited_once()


class TestChatMessageRepositoryUpdateStructured:
    @pytest.mark.asyncio
    async def test_updates_and_returns_message(self):
        db = _mock_db()
        msg = _make_msg_mock()
        db.execute.return_value = _result_with_scalar(msg)
        repo = ChatMessageRepository(db)

        new_structured = {"type": "event_actions", "actions": []}
        result = await repo.update_structured(msg.id, msg.chat_id, new_structured)

        assert result == msg
        assert msg.content_structured == new_structured
        db.commit.assert_awaited_once()
        db.refresh.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_scalar(None)
        repo = ChatMessageRepository(db)

        result = await repo.update_structured(uuid.uuid4(), uuid.uuid4(), {})

        assert result is None
        db.commit.assert_not_awaited()
