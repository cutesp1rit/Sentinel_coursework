import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.infrastructure.database.repositories.achievement_repository import AchievementRepository


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    db.add = MagicMock()
    db.flush = AsyncMock()
    return db


def _make_achievement(**kwargs) -> MagicMock:
    a = MagicMock()
    a.id = kwargs.get("id", uuid.uuid4())
    a.group_code = kwargs.get("group_code", "events_created")
    a.level = kwargs.get("level", 1)
    a.counter_name = kwargs.get("counter_name", "total_events")
    a.target_value = kwargs.get("target_value", 1)
    return a


def _result_with_list(items: list) -> MagicMock:
    result = MagicMock()
    scalars = MagicMock()
    scalars.all.return_value = items
    result.scalars.return_value = scalars
    return result


def _result_with_scalar(value) -> MagicMock:
    result = MagicMock()
    result.scalar.return_value = value
    return result


class TestGetAll:
    @pytest.mark.asyncio
    async def test_returns_all_achievements(self):
        db = _mock_db()
        achievements = [_make_achievement(), _make_achievement()]
        db.execute.return_value = _result_with_list(achievements)
        repo = AchievementRepository(db)

        result = await repo.get_all()

        assert result == achievements

    @pytest.mark.asyncio
    async def test_returns_empty_list_when_none(self):
        db = _mock_db()
        db.execute.return_value = _result_with_list([])
        repo = AchievementRepository(db)

        result = await repo.get_all()

        assert result == []


class TestGetByCounterNames:
    @pytest.mark.asyncio
    async def test_returns_matching_achievements(self):
        db = _mock_db()
        achievement = _make_achievement(counter_name="total_events")
        db.execute.return_value = _result_with_list([achievement])
        repo = AchievementRepository(db)

        result = await repo.get_by_counter_names({"total_events"})

        assert result == [achievement]


class TestHasAchievement:
    @pytest.mark.asyncio
    async def test_returns_true_when_has_achievement(self):
        db = _mock_db()
        result = MagicMock()
        result.scalar.return_value = 1
        db.execute.return_value = result
        repo = AchievementRepository(db)

        has = await repo.has_achievement(uuid.uuid4(), uuid.uuid4())

        assert has is True

    @pytest.mark.asyncio
    async def test_returns_false_when_no_achievement(self):
        db = _mock_db()
        result = MagicMock()
        result.scalar.return_value = 0
        db.execute.return_value = result
        repo = AchievementRepository(db)

        has = await repo.has_achievement(uuid.uuid4(), uuid.uuid4())

        assert has is False


class TestAward:
    @pytest.mark.asyncio
    async def test_awards_achievement_when_not_already_awarded(self):
        db = _mock_db()
        result = MagicMock()
        result.scalar.return_value = 0
        db.execute.return_value = result
        repo = AchievementRepository(db)

        ua = await repo.award(uuid.uuid4(), uuid.uuid4())

        db.add.assert_called_once()
        db.flush.assert_awaited_once()
        assert ua is not None

    @pytest.mark.asyncio
    async def test_returns_none_when_already_awarded(self):
        db = _mock_db()
        result = MagicMock()
        result.scalar.return_value = 1
        db.execute.return_value = result
        repo = AchievementRepository(db)

        ua = await repo.award(uuid.uuid4(), uuid.uuid4())

        assert ua is None
        db.add.assert_not_called()


class TestGetUserAchievements:
    @pytest.mark.asyncio
    async def test_returns_dict_keyed_by_achievement_id(self):
        db = _mock_db()
        achievement_id = uuid.uuid4()
        ua = MagicMock()
        ua.achievement_id = achievement_id
        db.execute.return_value = _result_with_list([ua])
        repo = AchievementRepository(db)

        result = await repo.get_user_achievements(uuid.uuid4())

        assert achievement_id in result
        assert result[achievement_id] == ua
