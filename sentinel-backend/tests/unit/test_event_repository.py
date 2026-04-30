import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, call

import pytest

from app.core.schemas.event import EventCreate, EventUpdate, EventSyncUpsert
from app.infrastructure.database.repositories.event_repository import EventRepository


def _mock_db() -> AsyncMock:
    db = AsyncMock()
    db.execute = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


def _make_event(**kwargs) -> MagicMock:
    e = MagicMock()
    e.id = kwargs.get("id", uuid.uuid4())
    e.user_id = kwargs.get("user_id", uuid.uuid4())
    e.title = kwargs.get("title", "Test Event")
    e.description = kwargs.get("description", None)
    e.start_at = kwargs.get("start_at", datetime(2026, 6, 1, 10, 0, tzinfo=timezone.utc))
    e.end_at = kwargs.get("end_at", None)
    e.all_day = kwargs.get("all_day", False)
    e.type = kwargs.get("type", "event")
    e.location = kwargs.get("location", None)
    e.is_fixed = kwargs.get("is_fixed", False)
    e.source = kwargs.get("source", "user")
    return e


def _result_with(scalars_list: list) -> MagicMock:
    result = MagicMock()
    scalars = MagicMock()
    scalars.all.return_value = scalars_list
    result.scalars.return_value = scalars
    result.scalar_one_or_none.return_value = scalars_list[0] if scalars_list else None
    return result


class TestGetById:
    @pytest.mark.asyncio
    async def test_returns_event_when_found(self):
        db = _mock_db()
        event = _make_event()
        db.execute.return_value = _result_with([event])
        repo = EventRepository(db)

        result = await repo.get_by_id(event.id, event.user_id)

        assert result == event

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with([])
        repo = EventRepository(db)

        result = await repo.get_by_id(uuid.uuid4(), uuid.uuid4())

        assert result is None


class TestSearch:
    @pytest.mark.asyncio
    async def test_returns_events_list(self):
        db = _mock_db()
        events = [_make_event(), _make_event()]
        result = MagicMock()
        scalars = MagicMock()
        scalars.all.return_value = events
        result.scalars.return_value = scalars
        db.execute.return_value = result
        repo = EventRepository(db)

        found = await repo.search(uuid.uuid4())

        assert found == events

    @pytest.mark.asyncio
    async def test_returns_empty_list_when_no_events(self):
        db = _mock_db()
        result = MagicMock()
        scalars = MagicMock()
        scalars.all.return_value = []
        result.scalars.return_value = scalars
        db.execute.return_value = result
        repo = EventRepository(db)

        found = await repo.search(uuid.uuid4())

        assert found == []

    @pytest.mark.asyncio
    async def test_search_with_date_range(self):
        db = _mock_db()
        result = MagicMock()
        scalars = MagicMock()
        scalars.all.return_value = []
        result.scalars.return_value = scalars
        db.execute.return_value = result
        repo = EventRepository(db)

        start = datetime(2026, 6, 1, tzinfo=timezone.utc)
        end = datetime(2026, 6, 30, tzinfo=timezone.utc)
        await repo.search(uuid.uuid4(), start_from=start, start_to=end)

        db.execute.assert_awaited_once()


class TestCreate:
    @pytest.mark.asyncio
    async def test_adds_event_and_commits(self):
        db = _mock_db()
        repo = EventRepository(db)
        user_id = uuid.uuid4()
        data = EventCreate(
            title="Meeting",
            start_at=datetime(2026, 6, 1, 10, 0, tzinfo=timezone.utc),
            type="event",
        )

        await repo.create(user_id, data)

        db.add.assert_called_once()
        db.commit.assert_awaited_once()
        db.refresh.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_created_event(self):
        db = _mock_db()
        repo = EventRepository(db)
        user_id = uuid.uuid4()
        data = EventCreate(
            title="Reminder",
            start_at=datetime(2026, 6, 1, 10, 0, tzinfo=timezone.utc),
            type="reminder",
        )

        result = await repo.create(user_id, data)

        assert result is not None


class TestUpdate:
    @pytest.mark.asyncio
    async def test_updates_fields_and_returns_event(self):
        db = _mock_db()
        event = _make_event(title="Old Title")
        db.execute.return_value = _result_with([event])
        repo = EventRepository(db)

        data = EventUpdate(title="New Title")
        result = await repo.update(event.id, event.user_id, data)

        assert event.title == "New Title"
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_none_when_event_not_found(self):
        db = _mock_db()
        db.execute.return_value = _result_with([])
        repo = EventRepository(db)

        result = await repo.update(uuid.uuid4(), uuid.uuid4(), EventUpdate(title="X"))

        assert result is None
        db.commit.assert_not_awaited()


class TestDelete:
    @pytest.mark.asyncio
    async def test_returns_true_when_deleted(self):
        db = _mock_db()
        result = MagicMock()
        result.rowcount = 1
        db.execute.return_value = result
        repo = EventRepository(db)

        deleted = await repo.delete(uuid.uuid4(), uuid.uuid4())

        assert deleted is True
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_returns_false_when_not_found(self):
        db = _mock_db()
        result = MagicMock()
        result.rowcount = 0
        db.execute.return_value = result
        repo = EventRepository(db)

        deleted = await repo.delete(uuid.uuid4(), uuid.uuid4())

        assert deleted is False


class TestGetEventsForDays:
    @pytest.mark.asyncio
    async def test_returns_empty_for_empty_ranges(self):
        db = _mock_db()
        repo = EventRepository(db)

        result = await repo.get_events_for_days(uuid.uuid4(), [])

        assert result == []
        db.execute.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_returns_events_for_ranges(self):
        db = _mock_db()
        events = [_make_event()]
        result = MagicMock()
        scalars = MagicMock()
        scalars.all.return_value = events
        result.scalars.return_value = scalars
        db.execute.return_value = result
        repo = EventRepository(db)

        start = datetime(2026, 6, 1, tzinfo=timezone.utc)
        end = datetime(2026, 6, 2, tzinfo=timezone.utc)
        found = await repo.get_events_for_days(uuid.uuid4(), [(start, end)])

        assert found == events


class TestBulkUpdateTimes:
    @pytest.mark.asyncio
    async def test_updates_event_times(self):
        db = _mock_db()
        event = _make_event()
        db.execute.return_value = _result_with([event])
        repo = EventRepository(db)

        new_start = datetime(2026, 7, 1, 9, 0, tzinfo=timezone.utc)
        new_end = datetime(2026, 7, 1, 10, 0, tzinfo=timezone.utc)
        await repo.bulk_update_times(event.user_id, [
            {"id": event.id, "start_at": new_start, "end_at": new_end}
        ])

        assert event.start_at == new_start
        assert event.end_at == new_end
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_skips_nonexistent_events(self):
        db = _mock_db()
        db.execute.return_value = _result_with([])
        repo = EventRepository(db)

        await repo.bulk_update_times(uuid.uuid4(), [
            {"id": uuid.uuid4(), "start_at": datetime(2026, 7, 1, tzinfo=timezone.utc), "end_at": None}
        ])

        db.commit.assert_awaited_once()


def _make_upsert(**kwargs) -> EventSyncUpsert:
    return EventSyncUpsert(
        id=kwargs.get("id", None),
        title=kwargs.get("title", "Synced Event"),
        start_at=kwargs.get("start_at", datetime(2026, 6, 1, 10, 0, tzinfo=timezone.utc)),
        end_at=kwargs.get("end_at", None),
        type=kwargs.get("type", "event"),
        source=kwargs.get("source", "user"),
    )


class TestSyncBatch:
    @pytest.mark.asyncio
    async def test_creates_new_event_when_no_id(self):
        db = _mock_db()
        db.execute.return_value = _result_with([])
        repo = EventRepository(db)

        upsert = _make_upsert()
        created, updated, deleted = await repo.sync_batch(uuid.uuid4(), [upsert], [])

        assert len(created) == 1
        assert len(updated) == 0
        db.add.assert_called_once()
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_updates_existing_event_when_id_matches(self):
        db = _mock_db()
        event = _make_event(title="Old Title")
        db.execute.return_value = _result_with([event])
        repo = EventRepository(db)

        upsert = _make_upsert(id=event.id, title="New Title")
        created, updated, deleted = await repo.sync_batch(event.user_id, [upsert], [])

        assert len(created) == 0
        assert len(updated) == 1
        assert event.title == "New Title"

    @pytest.mark.asyncio
    async def test_deletes_events_by_ids(self):
        db = _mock_db()
        event = _make_event()
        db.execute.return_value = _result_with([event])
        repo = EventRepository(db)

        created, updated, deleted = await repo.sync_batch(event.user_id, [], [event.id])

        assert len(deleted) == 1
        assert deleted[0] == event
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_empty_upserts_and_deletes_still_commits(self):
        db = _mock_db()
        repo = EventRepository(db)

        created, updated, deleted = await repo.sync_batch(uuid.uuid4(), [], [])

        assert created == []
        assert updated == []
        assert deleted == []
        db.commit.assert_awaited_once()
