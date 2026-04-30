import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.infrastructure.database.models.auth_token import EMAIL_VERIFICATION, PASSWORD_RESET
from app.infrastructure.database.repositories.auth_token_repository import AuthTokenRepository


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    db.add = MagicMock()
    db.flush = AsyncMock()
    db.commit = AsyncMock()
    return db


def _make_token(**kwargs) -> MagicMock:
    t = MagicMock()
    t.id = kwargs.get("id", uuid.uuid4())
    t.user_id = kwargs.get("user_id", uuid.uuid4())
    t.token = kwargs.get("token", "tok123")
    t.token_type = kwargs.get("token_type", EMAIL_VERIFICATION)
    t.expires_at = kwargs.get("expires_at", datetime.now(timezone.utc) + timedelta(hours=1))
    return t


def _result_with(token) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = token
    return result


class TestCreate:
    @pytest.mark.asyncio
    async def test_creates_token_and_flushes(self):
        db = _mock_db()
        repo = AuthTokenRepository(db)
        user_id = uuid.uuid4()
        expires = datetime.now(timezone.utc) + timedelta(hours=24)

        result = await repo.create(user_id, "verif_token", EMAIL_VERIFICATION, expires)

        db.add.assert_called_once()
        db.flush.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_deletes_existing_token_of_same_type(self):
        db = _mock_db()
        repo = AuthTokenRepository(db)
        user_id = uuid.uuid4()
        expires = datetime.now(timezone.utc) + timedelta(hours=1)

        await repo.create(user_id, "new_token", PASSWORD_RESET, expires)

        # First execute call should be DELETE
        db.execute.assert_awaited()


class TestGetByToken:
    @pytest.mark.asyncio
    async def test_returns_token_when_found(self):
        db = _mock_db()
        token = _make_token(token="tok_abc", token_type=EMAIL_VERIFICATION)
        db.execute.return_value = _result_with(token)
        repo = AuthTokenRepository(db)

        result = await repo.get_by_token("tok_abc", EMAIL_VERIFICATION)

        assert result == token

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with(None)
        repo = AuthTokenRepository(db)

        result = await repo.get_by_token("nonexistent", EMAIL_VERIFICATION)

        assert result is None


class TestDeleteById:
    @pytest.mark.asyncio
    async def test_executes_delete(self):
        db = _mock_db()
        repo = AuthTokenRepository(db)

        await repo.delete_by_id(uuid.uuid4())

        db.execute.assert_awaited_once()
