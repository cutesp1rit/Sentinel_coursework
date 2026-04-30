import uuid
from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.core.schemas.event import EventCreate, EventUpdate
from app.core.schemas.chat import EventAction


START = datetime(2026, 4, 10, 10, 0, tzinfo=timezone.utc)
END = datetime(2026, 4, 10, 11, 0, tzinfo=timezone.utc)


class TestEventCreateValidation:
    def test_valid_event(self):
        e = EventCreate(title="Meeting", start_at=START, end_at=END)
        assert e.title == "Meeting"

    def test_end_before_start_rejected(self):
        with pytest.raises(ValidationError):
            EventCreate(title="Meeting", start_at=END, end_at=START)

    def test_end_equals_start_rejected(self):
        with pytest.raises(ValidationError):
            EventCreate(title="Meeting", start_at=START, end_at=START)

    def test_no_end_at_allowed(self):
        e = EventCreate(title="Take pills", start_at=START)
        assert e.end_at is None

    def test_empty_title_rejected(self):
        with pytest.raises(ValidationError):
            EventCreate(title="", start_at=START)

    def test_source_defaults_to_user(self):
        e = EventCreate(title="Meeting", start_at=START)
        assert e.source == "user"

    def test_source_ai_allowed(self):
        e = EventCreate(title="AI meeting", start_at=START, source="ai")
        assert e.source == "ai"

    def test_title_too_long_rejected(self):
        with pytest.raises(ValidationError):
            EventCreate(title="A" * 256, start_at=START)


class TestEventUpdateValidation:
    def test_fully_empty_update_allowed(self):
        u = EventUpdate()
        assert u.title is None

    def test_partial_update_valid(self):
        u = EventUpdate(title="New title")
        assert u.title == "New title"

    def test_empty_title_in_update_rejected(self):
        with pytest.raises(ValidationError):
            EventUpdate(title="")

    def test_end_before_start_in_update_not_caught(self):
        # EventUpdate doesn't know the current start_at — validation is intentionally absent here.
        # Cross-field checks happen at the service/repository layer.
        u = EventUpdate(end_at=datetime(2020, 1, 1, tzinfo=timezone.utc))
        assert u.end_at is not None


class TestEventActionValidation:
    def test_create_action_requires_payload(self):
        with pytest.raises(ValidationError):
            EventAction(action="create")

    def test_update_action_requires_event_id(self):
        with pytest.raises(ValidationError):
            EventAction(action="update", payload=EventUpdate(title="X"))

    def test_update_action_requires_payload(self):
        with pytest.raises(ValidationError):
            EventAction(action="update", event_id=uuid.uuid4())

    def test_delete_action_requires_event_id(self):
        with pytest.raises(ValidationError):
            EventAction(action="delete")

    def test_create_action_valid(self):
        payload = EventCreate(title="Meeting", start_at=START)
        a = EventAction(action="create", payload=payload)
        assert a.status == "pending"

    def test_delete_action_valid(self):
        a = EventAction(action="delete", event_id=uuid.uuid4())
        assert a.action == "delete"

    def test_action_status_defaults_to_pending(self):
        payload = EventCreate(title="Meeting", start_at=START)
        a = EventAction(action="create", payload=payload)
        assert a.status == "pending"
