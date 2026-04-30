import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.services.achievement_service import AchievementService
from app.infrastructure.database.models.achievement import UserAchievement


def _make_service():
    db = AsyncMock()
    db.commit = AsyncMock()
    svc = AchievementService(db)
    svc.counter_repo = AsyncMock()
    svc.counter_repo.increment = AsyncMock()
    svc.counter_repo.recompute_active_days = AsyncMock()
    svc.counter_repo.get_all = AsyncMock(return_value={})
    svc.repo = AsyncMock()
    svc.repo.get_by_counter_names = AsyncMock(return_value=[])
    return svc


@pytest.mark.asyncio
class TestHandleEventCreated:
    async def test_increments_total_events(self):
        svc = _make_service()
        await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        svc.counter_repo.increment.assert_any_await(svc.counter_repo.increment.call_args_list[0].args[0], "total_events")

    async def test_increments_ai_events_when_source_is_ai(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_created(user_id, {"source": "ai", "type": "event"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert any("ai_events" in c for c in calls)

    async def test_does_not_increment_ai_events_for_user_source(self):
        svc = _make_service()
        await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert not any("ai_events" in c for c in calls)

    async def test_increments_total_reminders_for_reminder_type(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_created(user_id, {"source": "user", "type": "reminder"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert any("total_reminders" in c for c in calls)

    async def test_does_not_increment_reminders_for_event_type(self):
        svc = _make_service()
        await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert not any("total_reminders" in c for c in calls)

    async def test_recomputes_active_days(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_created(user_id, {"source": "user", "type": "event"})
        svc.counter_repo.recompute_active_days.assert_awaited_once_with(user_id)

    async def test_commits_after_counters(self):
        svc = _make_service()
        await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        svc.db.commit.assert_awaited()

    async def test_returns_list_of_awarded_achievements(self):
        svc = _make_service()
        result = await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        assert isinstance(result, list)

    async def test_awards_achievement_when_threshold_reached(self):
        svc = _make_service()
        achievement = MagicMock()
        achievement.id = uuid.uuid4()
        achievement.counter_name = "total_events"
        achievement.target_value = 1
        svc.repo.get_by_counter_names = AsyncMock(return_value=[achievement])
        svc.counter_repo.get_all = AsyncMock(return_value={"total_events": 5})
        svc.repo.has_achievement = AsyncMock(return_value=False)
        ua = MagicMock(spec=UserAchievement)
        svc.repo.award = AsyncMock(return_value=ua)

        result = await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        assert ua in result

    async def test_skips_already_awarded_achievement(self):
        svc = _make_service()
        achievement = MagicMock()
        achievement.id = uuid.uuid4()
        achievement.counter_name = "total_events"
        achievement.target_value = 1
        svc.repo.get_by_counter_names = AsyncMock(return_value=[achievement])
        svc.counter_repo.get_all = AsyncMock(return_value={"total_events": 5})
        svc.repo.has_achievement = AsyncMock(return_value=True)

        result = await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        assert result == []

    async def test_no_award_when_below_threshold(self):
        svc = _make_service()
        achievement = MagicMock()
        achievement.id = uuid.uuid4()
        achievement.counter_name = "total_events"
        achievement.target_value = 100
        svc.repo.get_by_counter_names = AsyncMock(return_value=[achievement])
        svc.counter_repo.get_all = AsyncMock(return_value={"total_events": 1})
        svc.repo.has_achievement = AsyncMock(return_value=False)

        result = await svc.handle_event_created(uuid.uuid4(), {"source": "user", "type": "event"})
        assert result == []


@pytest.mark.asyncio
class TestHandleEventDeleted:
    async def test_decrements_total_events(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_deleted(user_id, {"source": "user", "type": "event"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert any("total_events" in c and "-1" in c for c in calls)

    async def test_decrements_ai_events_for_ai_source(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_deleted(user_id, {"source": "ai", "type": "event"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert any("ai_events" in c and "-1" in c for c in calls)

    async def test_decrements_reminders_for_reminder_type(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_deleted(user_id, {"source": "user", "type": "reminder"})
        calls = [str(c) for c in svc.counter_repo.increment.call_args_list]
        assert any("total_reminders" in c and "-1" in c for c in calls)

    async def test_recomputes_active_days(self):
        svc = _make_service()
        user_id = uuid.uuid4()
        await svc.handle_event_deleted(user_id, {"source": "user", "type": "event"})
        svc.counter_repo.recompute_active_days.assert_awaited_once_with(user_id)

    async def test_commits(self):
        svc = _make_service()
        await svc.handle_event_deleted(uuid.uuid4(), {"source": "user", "type": "event"})
        svc.db.commit.assert_awaited()
