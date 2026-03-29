import uuid
from datetime import datetime, timezone

import pytest

from app.core.services.llm_service import LLMService


def svc() -> LLMService:
    # client не используется в тестируемых методах
    return LLMService(client=None)


class TestParseDatetime:
    def test_valid_iso_string(self):
        result = LLMService._parse_dt("2026-04-10T10:00:00")
        assert result == datetime(2026, 4, 10, 10, 0, 0)

    def test_valid_iso_with_timezone(self):
        result = LLMService._parse_dt("2026-04-10T10:00:00+03:00")
        assert result is not None
        assert result.year == 2026

    def test_none_returns_none(self):
        assert LLMService._parse_dt(None) is None

    def test_invalid_string_returns_none(self):
        assert LLMService._parse_dt("завтра в 10") is None

    def test_empty_string_returns_none(self):
        assert LLMService._parse_dt("") is None

    def test_partial_date_without_time(self):
        # "2026-04-10" — не ISO datetime, но fromisoformat принимает
        result = LLMService._parse_dt("2026-04-10")
        assert result is not None


class TestBuildAction:
    def test_create_event_returns_action(self):
        action = svc()._build_action("create_event", {
            "title": "Meeting",
            "start_at": "2026-04-10T10:00:00+00:00",
            "end_at": "2026-04-10T11:00:00+00:00",
        })
        assert action is not None
        assert action.action == "create"
        assert action.payload.title == "Meeting"
        assert action.payload.source == "ai"

    def test_create_event_missing_required_title_returns_none(self):
        action = svc()._build_action("create_event", {
            "start_at": "2026-04-10T10:00:00+00:00",
        })
        assert action is None

    def test_create_event_missing_start_at_returns_none(self):
        action = svc()._build_action("create_event", {"title": "Meeting"})
        assert action is None

    def test_update_event_valid(self):
        event_id = uuid.uuid4()
        action = svc()._build_action("update_event", {
            "event_id": str(event_id),
            "title": "Updated",
        })
        assert action is not None
        assert action.action == "update"
        assert action.event_id == event_id

    def test_update_event_missing_event_id_returns_none(self):
        action = svc()._build_action("update_event", {"title": "X"})
        assert action is None

    def test_update_event_invalid_uuid_returns_none(self):
        action = svc()._build_action("update_event", {
            "event_id": "not-a-uuid",
            "title": "X",
        })
        assert action is None

    def test_delete_event_valid(self):
        event_id = uuid.uuid4()
        action = svc()._build_action("delete_event", {"event_id": str(event_id)})
        assert action is not None
        assert action.action == "delete"
        assert action.event_id == event_id

    def test_delete_event_missing_id_returns_none(self):
        action = svc()._build_action("delete_event", {})
        assert action is None

    def test_delete_event_invalid_uuid_returns_none(self):
        action = svc()._build_action("delete_event", {"event_id": "garbage"})
        assert action is None


class TestBuildSystemPrompt:
    def test_prompt_contains_timezone(self):
        prompt = LLMService._build_system_prompt("Europe/Moscow")
        assert "Europe/Moscow" in prompt

    def test_invalid_timezone_falls_back_to_utc(self):
        prompt = LLMService._build_system_prompt("Mars/Olympus")
        assert "UTC" in prompt

    def test_prompt_contains_current_date(self):
        prompt = LLMService._build_system_prompt("UTC")
        year = str(datetime.now(timezone.utc).year)
        assert year in prompt

    def test_prompt_mentions_confirmation_required(self):
        # Критически важно: пользователь должен подтверждать действия
        prompt = LLMService._build_system_prompt("UTC")
        assert "confirm" in prompt.lower() or "confirm" in prompt
