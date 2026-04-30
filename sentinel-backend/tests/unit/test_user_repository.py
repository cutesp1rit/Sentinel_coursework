import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.schemas.user import UpdateProfileRequest, UserCreate
from app.infrastructure.database.repositories.user_repository import UserRepository


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.delete = AsyncMock()
    db.flush = AsyncMock()
    return db


def _make_user(**kwargs) -> MagicMock:
    u = MagicMock()
    u.id = kwargs.get("id", uuid.uuid4())
    u.email = kwargs.get("email", "user@example.com")
    u.timezone = kwargs.get("timezone", "Europe/Moscow")
    u.locale = kwargs.get("locale", "ru-RU")
    u.ai_instructions = kwargs.get("ai_instructions", None)
    u.is_verified = kwargs.get("is_verified", False)
    return u


def _result_with_user(user) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = user
    return result


class TestGetByEmail:
    @pytest.mark.asyncio
    async def test_returns_user_when_found(self):
        db = _mock_db()
        user = _make_user(email="found@example.com")
        db.execute.return_value = _result_with_user(user)
        repo = UserRepository(db)

        result = await repo.get_by_email("found@example.com")

        assert result == user

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_user(None)
        repo = UserRepository(db)

        result = await repo.get_by_email("missing@example.com")

        assert result is None


class TestGetById:
    @pytest.mark.asyncio
    async def test_returns_user_when_found(self):
        db = _mock_db()
        user = _make_user()
        db.execute.return_value = _result_with_user(user)
        repo = UserRepository(db)

        result = await repo.get_by_id(user.id)

        assert result == user

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_user(None)
        repo = UserRepository(db)

        result = await repo.get_by_id(uuid.uuid4())

        assert result is None


class TestCreate:
    @pytest.mark.asyncio
    async def test_adds_user_and_commits(self):
        db = _mock_db()
        repo = UserRepository(db)
        data = UserCreate(email="new@example.com", password="StrongPass1!")

        await repo.create(data)

        db.add.assert_called_once()
        db.commit.assert_awaited_once()
        db.refresh.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_created_user(self):
        db = _mock_db()
        repo = UserRepository(db)
        data = UserCreate(email="new@example.com", password="StrongPass1!")

        result = await repo.create(data)

        assert result is not None


class TestSetVerified:
    @pytest.mark.asyncio
    async def test_executes_update(self):
        db = _mock_db()
        repo = UserRepository(db)

        await repo.set_verified(uuid.uuid4())

        db.execute.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_does_not_commit(self):
        db = _mock_db()
        repo = UserRepository(db)

        await repo.set_verified(uuid.uuid4())

        db.commit.assert_not_awaited()


class TestUpdateProfile:
    @pytest.mark.asyncio
    async def test_updates_timezone(self):
        db = _mock_db()
        user = _make_user(timezone="Europe/Moscow")
        db.execute.return_value = _result_with_user(user)
        repo = UserRepository(db)

        data = UpdateProfileRequest(timezone="America/New_York")
        await repo.update_profile(user.id, data)

        assert user.timezone == "America/New_York"
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_updates_ai_instructions(self):
        db = _mock_db()
        user = _make_user()
        db.execute.return_value = _result_with_user(user)
        repo = UserRepository(db)

        data = UpdateProfileRequest(ai_instructions="Be concise")
        await repo.update_profile(user.id, data)

        assert user.ai_instructions == "Be concise"

    @pytest.mark.asyncio
    async def test_returns_none_when_user_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with_user(None)
        repo = UserRepository(db)

        result = await repo.update_profile(uuid.uuid4(), UpdateProfileRequest())

        assert result is None


class TestDelete:
    @pytest.mark.asyncio
    async def test_deletes_user_and_flushes(self):
        db = _mock_db()
        user = _make_user()
        repo = UserRepository(db)

        await repo.delete(user)

        db.delete.assert_awaited_once_with(user)
        db.flush.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_does_not_commit(self):
        db = _mock_db()
        user = _make_user()
        repo = UserRepository(db)

        await repo.delete(user)

        db.commit.assert_not_awaited()


class TestUpdateLastLogin:
    @pytest.mark.asyncio
    async def test_executes_update_and_commits(self):
        db = _mock_db()
        repo = UserRepository(db)

        await repo.update_last_login(uuid.uuid4())

        db.execute.assert_awaited_once()
        db.commit.assert_awaited_once()


class TestUpdatePassword:
    @pytest.mark.asyncio
    async def test_executes_update(self):
        db = _mock_db()
        repo = UserRepository(db)

        await repo.update_password(uuid.uuid4(), "new_hash")

        db.execute.assert_awaited_once()
