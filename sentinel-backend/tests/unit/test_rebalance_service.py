"""Unit tests for RebalanceService — no DB, no real LLM."""
import json
import uuid
from datetime import date, datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock
from zoneinfo import ZoneInfo

import pytest

from app.core.schemas.rebalance import (
    ApplyEventChange,
    RebalanceApplyRequest,
    RebalanceDay,
    RebalanceRequest,
)
from app.core.services.rebalance_service import RebalanceService, RebalanceValidationError
from app.infrastructure.database.models import Event


MSK = ZoneInfo("Europe/Moscow")
UTC = timezone.utc


# --- Helpers ---

def _event(
    *,
    event_id: uuid.UUID | None = None,
    title: str = "Meeting",
    start_at: datetime,
    end_at: datetime | None = None,
    is_fixed: bool = False,
    description: str | None = None,
) -> Event:
    e = MagicMock(spec=Event)
    e.id = event_id or uuid.uuid4()
    e.title = title
    e.start_at = start_at
    e.end_at = end_at
    e.is_fixed = is_fixed
    e.description = description
    return e


def _make_llm_client(response_json: dict) -> MagicMock:
    mock_msg = MagicMock()
    mock_msg.content = json.dumps(response_json)
    mock_choice = MagicMock()
    mock_choice.message = mock_msg
    mock_resp = MagicMock()
    mock_resp.choices = [mock_choice]
    client = MagicMock()
    client.chat = MagicMock()
    client.chat.completions = MagicMock()
    client.chat.completions.create = AsyncMock(return_value=mock_resp)
    return client


def _svc(llm_response: dict | None = None) -> RebalanceService:
    client = _make_llm_client(llm_response or {"events": [], "summary": "ok"})
    return RebalanceService(client)


# --- Tests for _events_to_llm_list ---

class TestEventsToLlmList:
    def _svc(self):
        return RebalanceService(MagicMock())

    def test_reminder_marked_as_fixed(self):
        e = _event(start_at=datetime(2026, 4, 25, 9, tzinfo=MSK), end_at=None, is_fixed=False)
        result = self._svc()._events_to_llm_list([e], MSK)
        assert result[0]["is_fixed"] is True

    def test_regular_non_fixed_event_not_marked_fixed(self):
        e = _event(start_at=datetime(2026, 4, 25, 9, tzinfo=MSK),
                   end_at=datetime(2026, 4, 25, 10, tzinfo=MSK), is_fixed=False)
        result = self._svc()._events_to_llm_list([e], MSK)
        assert result[0]["is_fixed"] is False

    def test_fixed_event_stays_fixed(self):
        e = _event(start_at=datetime(2026, 4, 25, 9, tzinfo=MSK),
                   end_at=datetime(2026, 4, 25, 10, tzinfo=MSK), is_fixed=True)
        result = self._svc()._events_to_llm_list([e], MSK)
        assert result[0]["is_fixed"] is True

    def test_reminder_has_no_end_at_in_output(self):
        e = _event(start_at=datetime(2026, 4, 25, 9, tzinfo=MSK), end_at=None)
        result = self._svc()._events_to_llm_list([e], MSK)
        assert "end_at" not in result[0]


# --- Tests for _build_workload_summary ---

class TestBuildWorkloadSummary:
    def _call(self, events_json, days):
        return RebalanceService._build_workload_summary(events_json, days)

    def test_free_day_shown_correctly(self):
        days = [RebalanceDay(date=date(2026, 4, 26))]
        summary = self._call([], days)
        assert "2026-04-26" in summary
        assert "0 events" in summary
        assert "0.0h busy" in summary

    def test_busy_hours_calculated_correctly(self):
        events = [{
            "id": str(uuid.uuid4()), "title": "Work",
            "start_at": "2026-04-25T09:00:00+03:00",
            "end_at": "2026-04-25T11:00:00+03:00",
            "is_fixed": False,
        }]
        days = [RebalanceDay(date=date(2026, 4, 25))]
        summary = self._call(events, days)
        assert "2.0h busy" in summary

    def test_movable_count_excludes_fixed(self):
        eid1, eid2 = str(uuid.uuid4()), str(uuid.uuid4())
        events = [
            {"id": eid1, "title": "Fixed", "start_at": "2026-04-25T09:00:00+03:00",
             "end_at": "2026-04-25T10:00:00+03:00", "is_fixed": True},
            {"id": eid2, "title": "Free", "start_at": "2026-04-25T11:00:00+03:00",
             "end_at": "2026-04-25T12:00:00+03:00", "is_fixed": False},
        ]
        days = [RebalanceDay(date=date(2026, 4, 25))]
        summary = self._call(events, days)
        assert "1 movable" in summary

    def test_multiple_days_all_present(self):
        days = [RebalanceDay(date=date(2026, 4, 25)), RebalanceDay(date=date(2026, 4, 26))]
        summary = self._call([], days)
        assert "2026-04-25" in summary
        assert "2026-04-26" in summary


# --- Tests for _exclude_multiday ---

class TestExcludeMultiday:
    def _call(self, events, days, tz=MSK):
        return RebalanceService._exclude_multiday(events, days, tz)

    def test_single_day_event_included(self):
        e = _event(start_at=datetime(2026, 4, 25, 10, tzinfo=MSK),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=MSK))
        days = [RebalanceDay(date=date(2026, 4, 25))]
        result = self._call([e], days)
        assert e in result

    def test_reminder_without_end_included(self):
        e = _event(start_at=datetime(2026, 4, 25, 9, tzinfo=MSK), end_at=None)
        days = [RebalanceDay(date=date(2026, 4, 25))]
        result = self._call([e], days)
        assert e in result

    def test_multiday_event_not_covering_all_selected_excluded(self):
        # Event spans Mon-Tue, user selects Mon+Wed → excluded
        e = _event(
            start_at=datetime(2026, 4, 25, 10, tzinfo=MSK),
            end_at=datetime(2026, 4, 26, 10, tzinfo=MSK),
        )
        days = [RebalanceDay(date=date(2026, 4, 25)), RebalanceDay(date=date(2026, 4, 27))]
        result = self._call([e], days)
        assert e not in result

    def test_multiday_event_covering_all_selected_included(self):
        # Event spans Mon-Wed, user selects Mon+Tue → event covers both → included
        e = _event(
            start_at=datetime(2026, 4, 25, 10, tzinfo=MSK),
            end_at=datetime(2026, 4, 27, 10, tzinfo=MSK),
        )
        days = [RebalanceDay(date=date(2026, 4, 25)), RebalanceDay(date=date(2026, 4, 26))]
        result = self._call([e], days)
        assert e in result


# --- Tests for _validate_llm_events ---

class TestValidateLlmEvents:
    def _svc(self):
        return RebalanceService(MagicMock())

    def _original_by_id(self, events):
        return {str(e.id): e for e in events}

    def test_valid_response_passes(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        llm = [{"id": str(eid), "start_at": "2026-04-25T10:00:00+00:00", "end_at": "2026-04-25T11:00:00+00:00"}]
        self._svc()._validate_llm_events(llm, self._original_by_id([e]))

    def test_missing_event_raises(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC))
        llm = []  # LLM dropped the event
        with pytest.raises(RebalanceValidationError, match="dropped"):
            self._svc()._validate_llm_events(llm, self._original_by_id([e]))

    def test_unknown_id_raises(self):
        llm = [{"id": str(uuid.uuid4()), "start_at": "2026-04-25T10:00:00+00:00"}]
        with pytest.raises(RebalanceValidationError, match="unknown"):
            self._svc()._validate_llm_events(llm, {})

    def test_end_before_start_raises(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        llm = [{"id": str(eid), "start_at": "2026-04-25T11:00:00+00:00",
                "end_at": "2026-04-25T10:00:00+00:00"}]
        with pytest.raises(RebalanceValidationError, match="end_at must be after"):
            self._svc()._validate_llm_events(llm, self._original_by_id([e]))

    def test_overlap_raises(self):
        id1, id2 = uuid.uuid4(), uuid.uuid4()
        e1 = _event(event_id=id1, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                    end_at=datetime(2026, 4, 25, 12, tzinfo=UTC))
        e2 = _event(event_id=id2, start_at=datetime(2026, 4, 25, 11, tzinfo=UTC),
                    end_at=datetime(2026, 4, 25, 13, tzinfo=UTC))
        llm = [
            {"id": str(id1), "start_at": "2026-04-25T10:00:00+00:00", "end_at": "2026-04-25T12:00:00+00:00"},
            {"id": str(id2), "start_at": "2026-04-25T11:00:00+00:00", "end_at": "2026-04-25T13:00:00+00:00"},
        ]
        with pytest.raises(RebalanceValidationError, match="overlap"):
            self._svc()._validate_llm_events(llm, {str(id1): e1, str(id2): e2})

    def test_reminder_end_at_equal_start_passes(self):
        # LLM sometimes echoes end_at=start_at for reminders — should not raise
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC), end_at=None)
        llm = [{"id": str(eid), "start_at": "2026-04-25T10:00:00+00:00",
                "end_at": "2026-04-25T10:00:00+00:00"}]
        self._svc()._validate_llm_events(llm, self._original_by_id([e]))  # must not raise

    def test_non_overlapping_events_pass(self):
        id1, id2 = uuid.uuid4(), uuid.uuid4()
        e1 = _event(event_id=id1, start_at=datetime(2026, 4, 25, 9, tzinfo=UTC),
                    end_at=datetime(2026, 4, 25, 10, tzinfo=UTC))
        e2 = _event(event_id=id2, start_at=datetime(2026, 4, 25, 11, tzinfo=UTC),
                    end_at=datetime(2026, 4, 25, 12, tzinfo=UTC))
        llm = [
            {"id": str(id1), "start_at": "2026-04-25T09:00:00+00:00", "end_at": "2026-04-25T10:00:00+00:00"},
            {"id": str(id2), "start_at": "2026-04-25T11:00:00+00:00", "end_at": "2026-04-25T12:00:00+00:00"},
        ]
        self._svc()._validate_llm_events(llm, {str(id1): e1, str(id2): e2})


# --- Tests for _build_response ---

class TestBuildResponse:
    def _svc(self):
        return RebalanceService(MagicMock())

    def test_unchanged_event_marked_correctly(self):
        eid = uuid.uuid4()
        orig_start = datetime(2026, 4, 25, 10, tzinfo=UTC)
        orig_end = datetime(2026, 4, 25, 11, tzinfo=UTC)
        e = _event(event_id=eid, start_at=orig_start, end_at=orig_end)

        llm_output = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T13:00:00+03:00",
                         "end_at": "2026-04-25T14:00:00+03:00"}],
            "summary": "ok",
        }
        result = self._svc()._build_response([e], llm_output, MSK)
        # +03:00 13:00 = UTC 10:00, same as original → not changed
        assert result.proposed[0].changed is False

    def test_moved_event_marked_changed(self):
        eid = uuid.uuid4()
        orig_start = datetime(2026, 4, 25, 10, tzinfo=UTC)
        orig_end = datetime(2026, 4, 25, 11, tzinfo=UTC)
        e = _event(event_id=eid, start_at=orig_start, end_at=orig_end)

        llm_output = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T15:00:00+03:00",
                         "end_at": "2026-04-25T16:00:00+03:00"}],
            "summary": "Moved later",
        }
        result = self._svc()._build_response([e], llm_output, MSK)
        assert result.proposed[0].changed is True

    def test_counts_are_correct(self):
        ids = [uuid.uuid4() for _ in range(3)]
        events = [
            _event(event_id=ids[0], start_at=datetime(2026, 4, 25, 9, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 10, tzinfo=UTC)),
            _event(event_id=ids[1], start_at=datetime(2026, 4, 25, 11, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 12, tzinfo=UTC)),
            _event(event_id=ids[2], start_at=datetime(2026, 4, 25, 14, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 15, tzinfo=UTC)),
        ]
        llm_output = {
            "events": [
                # keep first as-is: UTC 9:00 = MSK 12:00
                {"id": str(ids[0]), "start_at": "2026-04-25T12:00:00+03:00", "end_at": "2026-04-25T13:00:00+03:00"},
                # move second: UTC 11:00→13:00, MSK 14:00→16:00
                {"id": str(ids[1]), "start_at": "2026-04-25T16:00:00+03:00", "end_at": "2026-04-25T17:00:00+03:00"},
                # move third: UTC 14:00→15:00, MSK 17:00→18:00
                {"id": str(ids[2]), "start_at": "2026-04-25T18:00:00+03:00", "end_at": "2026-04-25T19:00:00+03:00"},
            ],
            "summary": "Reordered",
        }
        result = self._svc()._build_response(events, llm_output, MSK)
        assert result.changed_count == 2
        assert result.unchanged_count == 1

    def test_summary_propagated(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC))
        llm_output = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T13:00:00+03:00"}],
            "summary": "Перенёс тяжёлые задачи на утро",
        }
        result = self._svc()._build_response([e], llm_output, MSK)
        assert result.summary == "Перенёс тяжёлые задачи на утро"

    def test_reminder_without_end_preserved(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC), end_at=None)
        llm_output = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T14:00:00+03:00"}],
            "summary": "ok",
        }
        result = self._svc()._build_response([e], llm_output, MSK)
        assert result.proposed[0].end_at is None


# --- Tests for propose (full flow with mocked LLM) ---

class TestPropose:
    def _make_request(self, dates=None, resource_battery=None):
        days = []
        for d in (dates or [date(2026, 4, 25)]):
            rb = resource_battery.get(d) if resource_battery else None
            days.append(RebalanceDay(date=d, resource_battery=rb))
        return RebalanceRequest(timezone="Europe/Moscow", days=days)

    def _make_repo(self, events):
        repo = AsyncMock()
        repo.get_events_for_days = AsyncMock(return_value=events)
        return repo

    @pytest.mark.asyncio
    async def test_empty_events_returns_empty_response(self):
        svc = _svc({"events": [], "summary": "Нет событий"})
        repo = self._make_repo([])
        result = await svc.propose(uuid.uuid4(), self._make_request(), repo)
        assert result.proposed == []
        assert result.changed_count == 0

    @pytest.mark.asyncio
    async def test_propose_returns_proposed_events(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        response = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T14:00:00+03:00",
                         "end_at": "2026-04-25T15:00:00+03:00"}],
            "summary": "Moved to afternoon",
        }
        svc = _svc(response)
        repo = self._make_repo([e])
        result = await svc.propose(uuid.uuid4(), self._make_request(), repo)
        assert len(result.proposed) == 1
        assert result.proposed[0].changed is True

    @pytest.mark.asyncio
    async def test_retry_on_validation_failure_then_success(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))

        bad_response = {"events": [], "summary": "oops"}  # drops the event — invalid
        good_response = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T14:00:00+03:00",
                         "end_at": "2026-04-25T15:00:00+03:00"}],
            "summary": "ok",
        }

        call_count = 0

        async def _side_effect(**kwargs):
            nonlocal call_count
            call_count += 1
            resp_data = bad_response if call_count == 1 else good_response
            msg = MagicMock()
            msg.content = json.dumps(resp_data)
            choice = MagicMock()
            choice.message = msg
            resp = MagicMock()
            resp.choices = [choice]
            return resp

        client = MagicMock()
        client.chat.completions.create = _side_effect
        svc = RebalanceService(client)
        repo = self._make_repo([e])
        result = await svc.propose(uuid.uuid4(), self._make_request(), repo)
        assert call_count == 2
        assert len(result.proposed) == 1

    @pytest.mark.asyncio
    async def test_two_failures_raises_validation_error(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))

        bad_response = {"events": [], "summary": "oops"}  # always drops the event
        svc = _svc(bad_response)
        repo = self._make_repo([e])
        with pytest.raises(RebalanceValidationError):
            await svc.propose(uuid.uuid4(), self._make_request(), repo)

    @pytest.mark.asyncio
    async def test_user_prompt_included_in_prompt(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        response = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T13:00:00+03:00",
                         "end_at": "2026-04-25T14:00:00+03:00"}],
            "summary": "ok",
        }
        captured = {}

        async def _capture(**kwargs):
            captured["messages"] = kwargs.get("messages", [])
            msg = MagicMock(); msg.content = json.dumps(response)
            choice = MagicMock(); choice.message = msg
            resp = MagicMock(); resp.choices = [choice]
            return resp

        client = MagicMock()
        client.chat.completions.create = _capture
        svc = RebalanceService(client)
        request = RebalanceRequest(
            timezone="Europe/Moscow",
            days=[RebalanceDay(date=date(2026, 4, 25))],
            user_prompt="Keep the evening completely free",
        )
        await svc.propose(uuid.uuid4(), request, self._make_repo([e]))
        prompt_text = captured["messages"][0]["content"]
        assert "Keep the evening completely free" in prompt_text

    @pytest.mark.asyncio
    async def test_no_user_prompt_section_absent(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        response = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T13:00:00+03:00",
                         "end_at": "2026-04-25T14:00:00+03:00"}],
            "summary": "ok",
        }
        captured = {}

        async def _capture(**kwargs):
            captured["messages"] = kwargs.get("messages", [])
            msg = MagicMock(); msg.content = json.dumps(response)
            choice = MagicMock(); choice.message = msg
            resp = MagicMock(); resp.choices = [choice]
            return resp

        client = MagicMock()
        client.chat.completions.create = _capture
        svc = RebalanceService(client)
        request = RebalanceRequest(
            timezone="Europe/Moscow",
            days=[RebalanceDay(date=date(2026, 4, 25))],
        )
        await svc.propose(uuid.uuid4(), request, self._make_repo([e]))
        prompt_text = captured["messages"][0]["content"]
        assert "personal request" not in prompt_text.lower()

    @pytest.mark.asyncio
    async def test_resource_battery_included_in_prompt(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        response = {
            "events": [{"id": str(eid), "start_at": "2026-04-25T13:00:00+03:00",
                         "end_at": "2026-04-25T14:00:00+03:00"}],
            "summary": "ok",
        }

        captured_prompt = {}

        async def _capture(**kwargs):
            captured_prompt["messages"] = kwargs.get("messages", [])
            msg = MagicMock()
            msg.content = json.dumps(response)
            choice = MagicMock()
            choice.message = msg
            resp = MagicMock()
            resp.choices = [choice]
            return resp

        client = MagicMock()
        client.chat.completions.create = _capture
        svc = RebalanceService(client)
        days = [RebalanceDay(date=date(2026, 4, 25), resource_battery=0.3)]
        request = RebalanceRequest(timezone="Europe/Moscow", days=days)
        repo = self._make_repo([e])
        await svc.propose(uuid.uuid4(), request, repo)

        prompt_text = captured_prompt["messages"][0]["content"]
        assert "30%" in prompt_text or "0.3" in prompt_text


# --- Tests for _compute_day_ranges_utc ---

class TestComputeDayRanges:
    def test_moscow_day_converted_to_utc(self):
        days = [RebalanceDay(date=date(2026, 4, 25))]
        ranges = RebalanceService._compute_day_ranges_utc(days, MSK)
        assert len(ranges) == 1
        start_utc, end_utc = ranges[0]
        # Moscow UTC+3: April 25 starts at UTC 21:00 April 24
        assert start_utc == datetime(2026, 4, 24, 21, 0, 0, tzinfo=UTC)
        assert end_utc == datetime(2026, 4, 25, 21, 0, 0, tzinfo=UTC)

    def test_multiple_days_produce_multiple_ranges(self):
        days = [RebalanceDay(date=date(2026, 4, 25)), RebalanceDay(date=date(2026, 4, 26))]
        ranges = RebalanceService._compute_day_ranges_utc(days, MSK)
        assert len(ranges) == 2


# --- Tests for _validate_apply_request ---

class TestValidateApplyRequest:
    def _make_repo(self, events_by_id: dict):
        repo = AsyncMock()

        async def _get(event_id, user_id):
            return events_by_id.get(event_id)

        repo.get_by_id = _get
        return repo

    @pytest.mark.asyncio
    async def test_valid_request_passes(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC))
        repo = self._make_repo({eid: e})
        svc = RebalanceService(MagicMock())
        changes = [ApplyEventChange(id=eid, start_at=datetime(2026, 4, 25, 12, tzinfo=UTC),
                                    end_at=datetime(2026, 4, 25, 13, tzinfo=UTC))]
        await svc._validate_apply_request(uuid.uuid4(), changes, repo)

    @pytest.mark.asyncio
    async def test_missing_event_raises(self):
        repo = self._make_repo({})
        svc = RebalanceService(MagicMock())
        changes = [ApplyEventChange(id=uuid.uuid4(), start_at=datetime(2026, 4, 25, 12, tzinfo=UTC))]
        with pytest.raises(ValueError, match="not found"):
            await svc._validate_apply_request(uuid.uuid4(), changes, repo)

    @pytest.mark.asyncio
    async def test_moving_fixed_event_raises(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC),
                   end_at=datetime(2026, 4, 25, 11, tzinfo=UTC), is_fixed=True)
        repo = self._make_repo({eid: e})
        svc = RebalanceService(MagicMock())
        changes = [ApplyEventChange(id=eid, start_at=datetime(2026, 4, 25, 14, tzinfo=UTC))]
        with pytest.raises(ValueError, match="fixed"):
            await svc._validate_apply_request(uuid.uuid4(), changes, repo)

    @pytest.mark.asyncio
    async def test_end_before_start_raises(self):
        eid = uuid.uuid4()
        e = _event(event_id=eid, start_at=datetime(2026, 4, 25, 10, tzinfo=UTC))
        repo = self._make_repo({eid: e})
        svc = RebalanceService(MagicMock())
        changes = [ApplyEventChange(
            id=eid,
            start_at=datetime(2026, 4, 25, 13, tzinfo=UTC),
            end_at=datetime(2026, 4, 25, 11, tzinfo=UTC),
        )]
        with pytest.raises(ValueError, match="end_at must be after"):
            await svc._validate_apply_request(uuid.uuid4(), changes, repo)
