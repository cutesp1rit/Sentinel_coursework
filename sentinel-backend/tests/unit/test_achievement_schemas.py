import uuid
from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.core.schemas.achievement import (
    AchievementLevel,
    AchievementGroup,
    AchievementsResponse,
)

UID = uuid.uuid4()
NOW = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)


def make_level(**kwargs) -> dict:
    defaults = {
        "id": UID,
        "level": 1,
        "title": "First Step",
        "description": "Created your first event",
        "icon": "🗓️",
        "target_value": 1,
        "unlocked": False,
        "earned_at": None,
    }
    return {**defaults, **kwargs}


def make_group(**kwargs) -> dict:
    defaults = {
        "group_code": "events_created",
        "category": "milestones",
        "counter_name": "total_events",
        "current_value": 0,
        "levels": [AchievementLevel(**make_level())],
    }
    return {**defaults, **kwargs}


class TestAchievementLevelSchema:
    def test_valid_locked_level(self):
        level = AchievementLevel(**make_level())
        assert level.unlocked is False
        assert level.earned_at is None

    def test_valid_unlocked_level(self):
        level = AchievementLevel(**make_level(unlocked=True, earned_at=NOW))
        assert level.unlocked is True
        assert level.earned_at == NOW

    def test_missing_title_rejected(self):
        data = make_level()
        del data["title"]
        with pytest.raises(ValidationError):
            AchievementLevel(**data)

    def test_missing_target_value_rejected(self):
        data = make_level()
        del data["target_value"]
        with pytest.raises(ValidationError):
            AchievementLevel(**data)

    def test_earned_at_none_when_locked(self):
        level = AchievementLevel(**make_level(unlocked=False, earned_at=None))
        assert level.earned_at is None

    def test_unlocked_with_earned_at(self):
        level = AchievementLevel(**make_level(unlocked=True, earned_at=NOW))
        assert level.earned_at is not None


class TestAchievementGroupSchema:
    def test_valid_group(self):
        group = AchievementGroup(**make_group())
        assert group.group_code == "events_created"
        assert group.current_value == 0
        assert len(group.levels) == 1

    def test_current_value_zero_is_valid(self):
        group = AchievementGroup(**make_group(current_value=0))
        assert group.current_value == 0

    def test_multiple_levels(self):
        levels = [
            AchievementLevel(**make_level(level=1, target_value=1)),
            AchievementLevel(**make_level(level=2, target_value=10)),
            AchievementLevel(**make_level(level=3, target_value=50)),
        ]
        group = AchievementGroup(**make_group(levels=levels))
        assert len(group.levels) == 3

    def test_missing_group_code_rejected(self):
        data = make_group()
        del data["group_code"]
        with pytest.raises(ValidationError):
            AchievementGroup(**data)

    def test_missing_counter_name_rejected(self):
        data = make_group()
        del data["counter_name"]
        with pytest.raises(ValidationError):
            AchievementGroup(**data)

    def test_empty_levels_list_is_valid(self):
        group = AchievementGroup(**make_group(levels=[]))
        assert group.levels == []


class TestAchievementsResponseSchema:
    def test_empty_groups(self):
        resp = AchievementsResponse(groups=[])
        assert resp.groups == []

    def test_multiple_groups(self):
        groups = [
            AchievementGroup(**make_group(group_code="events_created", counter_name="total_events")),
            AchievementGroup(**make_group(group_code="ai_assisted", counter_name="ai_events")),
        ]
        resp = AchievementsResponse(groups=groups)
        assert len(resp.groups) == 2
        assert resp.groups[0].group_code == "events_created"
        assert resp.groups[1].group_code == "ai_assisted"

    def test_current_value_independent_per_group(self):
        groups = [
            AchievementGroup(**make_group(group_code="events_created", current_value=7)),
            AchievementGroup(**make_group(group_code="ai_assisted", counter_name="ai_events", current_value=2)),
        ]
        resp = AchievementsResponse(groups=groups)
        assert resp.groups[0].current_value == 7
        assert resp.groups[1].current_value == 2


class TestProgressLogic:

    def test_progress_can_be_derived_from_current_and_target(self):
        level2 = AchievementLevel(**make_level(level=2, target_value=10, unlocked=False))
        group = AchievementGroup(**make_group(current_value=7, levels=[level2]))
        next_locked = next((l for l in group.levels if not l.unlocked), None)
        assert next_locked is not None
        pct = group.current_value / next_locked.target_value
        assert abs(pct - 0.7) < 0.001

    def test_all_unlocked_no_next_level(self):
        levels = [
            AchievementLevel(**make_level(level=1, target_value=1, unlocked=True, earned_at=NOW)),
            AchievementLevel(**make_level(level=2, target_value=10, unlocked=True, earned_at=NOW)),
        ]
        group = AchievementGroup(**make_group(current_value=15, levels=levels))
        next_locked = next((l for l in group.levels if not l.unlocked), None)
        assert next_locked is None

    def test_level_1_unlocked_level_2_not(self):
        levels = [
            AchievementLevel(**make_level(level=1, target_value=1, unlocked=True, earned_at=NOW)),
            AchievementLevel(**make_level(level=2, target_value=10, unlocked=False)),
        ]
        group = AchievementGroup(**make_group(current_value=3, levels=levels))
        unlocked = [l for l in group.levels if l.unlocked]
        locked = [l for l in group.levels if not l.unlocked]
        assert len(unlocked) == 1
        assert len(locked) == 1
        assert unlocked[0].level == 1
        assert locked[0].level == 2
