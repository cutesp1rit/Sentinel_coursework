import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.infrastructure.database.repositories.chat_repository import ChatMessageRepository


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
    scalars_mock.all.return_value = list(reversed(messages))  # DB returns newest-first

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
    async def test_non_image_structured_content_treated_as_plain_text(self):
        # event_actions content should fall through to plain text path
        structured = {"type": "event_actions", "actions": []}
        messages = [_make_message("assistant", "Here are the actions", content_structured=structured)]
        repo = _repo_with_messages(messages)

        history = await repo.get_recent_for_llm(uuid.uuid4(), limit=10)

        assert history[0]["content"] == "Here are the actions"
        assert isinstance(history[0]["content"], str)

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
