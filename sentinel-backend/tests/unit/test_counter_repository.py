import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.infrastructure.database.repositories.counter_repository import CounterRepository


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    return db


class TestIncrement:
    @pytest.mark.asyncio
    async def test_executes_upsert(self):
        db = _mock_db()
        repo = CounterRepository(db)

        await repo.increment(uuid.uuid4(), "total_events")

        db.execute.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_executes_with_negative_delta(self):
        db = _mock_db()
        repo = CounterRepository(db)

        await repo.increment(uuid.uuid4(), "total_events", delta=-1)

        db.execute.assert_awaited_once()


class TestSetCounter:
    @pytest.mark.asyncio
    async def test_executes_upsert(self):
        db = _mock_db()
        repo = CounterRepository(db)

        await repo.set_counter(uuid.uuid4(), "active_days", 5)

        db.execute.assert_awaited_once()


class TestGetAll:
    @pytest.mark.asyncio
    async def test_returns_dict_of_counters(self):
        db = _mock_db()
        counter = MagicMock()
        counter.counter_name = "total_events"
        counter.value = 3
        result = MagicMock()
        scalars = MagicMock()
        scalars.all.return_value = [counter]
        result.scalars.return_value = scalars
        db.execute.return_value = result
        repo = CounterRepository(db)

        counters = await repo.get_all(uuid.uuid4())

        assert counters == {"total_events": 3}

    @pytest.mark.asyncio
    async def test_returns_empty_dict_when_none(self):
        db = _mock_db()
        result = MagicMock()
        scalars = MagicMock()
        scalars.all.return_value = []
        result.scalars.return_value = scalars
        db.execute.return_value = result
        repo = CounterRepository(db)

        counters = await repo.get_all(uuid.uuid4())

        assert counters == {}


class TestRecomputeActiveDays:
    @pytest.mark.asyncio
    async def test_executes_count_query_and_updates_counter(self):
        db = _mock_db()
        count_result = MagicMock()
        count_result.scalar.return_value = 3
        db.execute.return_value = count_result
        repo = CounterRepository(db)

        result = await repo.recompute_active_days(uuid.uuid4())

        assert result == 3
        assert db.execute.await_count == 2

    @pytest.mark.asyncio
    async def test_returns_zero_when_no_events(self):
        db = _mock_db()
        count_result = MagicMock()
        count_result.scalar.return_value = None
        db.execute.return_value = count_result
        repo = CounterRepository(db)

        result = await repo.recompute_active_days(uuid.uuid4())

        assert result == 0
