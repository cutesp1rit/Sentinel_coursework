import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.infrastructure.database.repositories.idempotency_repository import IdempotencyRepository


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    return db


def _make_key(**kwargs) -> MagicMock:
    k = MagicMock()
    k.key = kwargs.get("key", "test-key")
    k.user_id = kwargs.get("user_id", uuid.uuid4())
    k.event_id = kwargs.get("event_id", uuid.uuid4())
    k.expires_at = kwargs.get("expires_at", datetime.now(timezone.utc) + timedelta(hours=1))
    return k


class TestGet:
    @pytest.mark.asyncio
    async def test_returns_key_when_found(self):
        db = _mock_db()
        key_obj = _make_key(key="abc")
        result = MagicMock()
        result.scalar_one_or_none.return_value = key_obj
        db.execute.return_value = result
        repo = IdempotencyRepository(db)

        found = await repo.get("abc", uuid.uuid4())

        assert found == key_obj
        db.execute.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        result = MagicMock()
        result.scalar_one_or_none.return_value = None
        db.execute.return_value = result
        repo = IdempotencyRepository(db)

        found = await repo.get("missing", uuid.uuid4())

        assert found is None


class TestSave:
    @pytest.mark.asyncio
    async def test_executes_insert(self):
        db = _mock_db()
        repo = IdempotencyRepository(db)

        await repo.save("key-1", uuid.uuid4(), uuid.uuid4())

        db.execute.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_does_not_raise(self):
        db = _mock_db()
        repo = IdempotencyRepository(db)

        await repo.save("key-2", uuid.uuid4(), uuid.uuid4())


class TestCleanupExpired:
    @pytest.mark.asyncio
    async def test_executes_delete(self):
        db = _mock_db()
        repo = IdempotencyRepository(db)

        await repo.cleanup_expired()

        db.execute.assert_awaited_once()
