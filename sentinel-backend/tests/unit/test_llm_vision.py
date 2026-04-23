import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from zoneinfo import ZoneInfo

from app.core.services.llm_service import LLMService


def _make_mock_client(response_text: str = "OK"):
    """Create an AsyncOpenAI mock that returns a single text response without tool calls."""
    mock_message = MagicMock()
    mock_message.tool_calls = None
    mock_message.content = response_text
    mock_message.model_dump.return_value = {"role": "assistant", "content": response_text}

    mock_choice = MagicMock()
    mock_choice.message = mock_message

    mock_response = MagicMock()
    mock_response.choices = [mock_choice]

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
    return mock_client


def _make_event_repo():
    return MagicMock()


class TestSystemPromptImageInstructions:
    def test_prompt_describes_image_analysis(self):
        tz = ZoneInfo("UTC")
        prompt = LLMService._build_system_prompt(tz, "UTC")
        assert "image" in prompt.lower()

    def test_prompt_instructs_to_propose_events_from_image(self):
        tz = ZoneInfo("UTC")
        prompt = LLMService._build_system_prompt(tz, "UTC")
        # Should instruct LLM to propose events when scheduling info found in image
        assert "propose" in prompt.lower() or "event" in prompt.lower()

    def test_prompt_contains_timezone_label(self):
        tz = ZoneInfo("Europe/Moscow")
        prompt = LLMService._build_system_prompt(tz, "Europe/Moscow")
        assert "Europe/Moscow" in prompt


class TestVisionEnabledFlag:
    @pytest.mark.asyncio
    async def test_images_sent_to_llm_when_vision_enabled(self):
        mock_client = _make_mock_client()
        svc = LLMService(client=mock_client)

        with patch("app.core.services.llm_service.settings") as mock_settings:
            mock_settings.LLM_VISION_ENABLED = True
            mock_settings.LLM_MODEL = "test-model"

            await svc.process_user_message(
                user_message="What is in this image?",
                history=[],
                user_id=uuid.uuid4(),
                user_timezone="UTC",
                event_repo=_make_event_repo(),
                images=[{"url": "https://example.com/photo.jpg", "filename": "photo.jpg", "mime_type": "image/jpeg"}],
            )

        call_kwargs = mock_client.chat.completions.create.call_args.kwargs
        messages = call_kwargs["messages"]
        user_msg = next(m for m in messages if m.get("role") == "user")

        # Content must be a list containing an image_url block
        assert isinstance(user_msg["content"], list)
        image_blocks = [b for b in user_msg["content"] if b.get("type") == "image_url"]
        assert len(image_blocks) == 1
        assert image_blocks[0]["image_url"]["url"] == "https://example.com/photo.jpg"

    @pytest.mark.asyncio
    async def test_images_not_sent_to_llm_when_vision_disabled(self):
        mock_client = _make_mock_client()
        svc = LLMService(client=mock_client)

        with patch("app.core.services.llm_service.settings") as mock_settings:
            mock_settings.LLM_VISION_ENABLED = False
            mock_settings.LLM_MODEL = "test-model"

            await svc.process_user_message(
                user_message="What is in this image?",
                history=[],
                user_id=uuid.uuid4(),
                user_timezone="UTC",
                event_repo=_make_event_repo(),
                images=[{"url": "https://example.com/photo.jpg", "filename": "photo.jpg", "mime_type": "image/jpeg"}],
            )

        call_kwargs = mock_client.chat.completions.create.call_args.kwargs
        messages = call_kwargs["messages"]
        user_msg = next(m for m in messages if m.get("role") == "user")

        # Content must be a plain string, no image blocks
        assert isinstance(user_msg["content"], str)
        assert user_msg["content"] == "What is in this image?"

    @pytest.mark.asyncio
    async def test_no_images_sends_plain_text_regardless_of_vision_flag(self):
        mock_client = _make_mock_client()
        svc = LLMService(client=mock_client)

        with patch("app.core.services.llm_service.settings") as mock_settings:
            mock_settings.LLM_VISION_ENABLED = True
            mock_settings.LLM_MODEL = "test-model"

            await svc.process_user_message(
                user_message="Hello!",
                history=[],
                user_id=uuid.uuid4(),
                user_timezone="UTC",
                event_repo=_make_event_repo(),
                images=None,
            )

        call_kwargs = mock_client.chat.completions.create.call_args.kwargs
        messages = call_kwargs["messages"]
        user_msg = next(m for m in messages if m.get("role") == "user")

        assert isinstance(user_msg["content"], str)
        assert user_msg["content"] == "Hello!"

    @pytest.mark.asyncio
    async def test_multiple_images_all_included_when_vision_enabled(self):
        mock_client = _make_mock_client()
        svc = LLMService(client=mock_client)

        images = [
            {"url": "https://example.com/img1.jpg", "filename": "img1.jpg", "mime_type": "image/jpeg"},
            {"url": "https://example.com/img2.jpg", "filename": "img2.jpg", "mime_type": "image/jpeg"},
        ]

        with patch("app.core.services.llm_service.settings") as mock_settings:
            mock_settings.LLM_VISION_ENABLED = True
            mock_settings.LLM_MODEL = "test-model"

            await svc.process_user_message(
                user_message="Compare these photos.",
                history=[],
                user_id=uuid.uuid4(),
                user_timezone="UTC",
                event_repo=_make_event_repo(),
                images=images,
            )

        call_kwargs = mock_client.chat.completions.create.call_args.kwargs
        messages = call_kwargs["messages"]
        user_msg = next(m for m in messages if m.get("role") == "user")

        assert isinstance(user_msg["content"], list)
        image_blocks = [b for b in user_msg["content"] if b.get("type") == "image_url"]
        assert len(image_blocks) == 2
        urls = {b["image_url"]["url"] for b in image_blocks}
        assert "https://example.com/img1.jpg" in urls
        assert "https://example.com/img2.jpg" in urls

    @pytest.mark.asyncio
    async def test_text_block_included_alongside_images(self):
        mock_client = _make_mock_client()
        svc = LLMService(client=mock_client)

        with patch("app.core.services.llm_service.settings") as mock_settings:
            mock_settings.LLM_VISION_ENABLED = True
            mock_settings.LLM_MODEL = "test-model"

            await svc.process_user_message(
                user_message="Schedule the event from this poster.",
                history=[],
                user_id=uuid.uuid4(),
                user_timezone="UTC",
                event_repo=_make_event_repo(),
                images=[{"url": "https://example.com/poster.jpg", "filename": "poster.jpg", "mime_type": "image/jpeg"}],
            )

        call_kwargs = mock_client.chat.completions.create.call_args.kwargs
        messages = call_kwargs["messages"]
        user_msg = next(m for m in messages if m.get("role") == "user")

        assert isinstance(user_msg["content"], list)
        text_blocks = [b for b in user_msg["content"] if b.get("type") == "text"]
        assert len(text_blocks) == 1
        assert text_blocks[0]["text"] == "Schedule the event from this poster."
