from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import or_, and_, select, delete
from typing import Optional, List
from datetime import datetime
import uuid

from app.infrastructure.database.models import Event
from app.core.schemas.event import EventCreate, EventSyncUpsert, EventUpdate


class EventRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, event_id: uuid.UUID, user_id: uuid.UUID) -> Optional[Event]:
        result = await self.db.execute(
            select(Event).where(Event.id == event_id, Event.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def search(
        self,
        user_id: uuid.UUID,
        start_from: Optional[datetime] = None,
        start_to: Optional[datetime] = None,
    ) -> List[Event]:
        query = select(Event).where(Event.user_id == user_id)

        if start_from is not None:
            query = query.where(Event.start_at >= start_from)
        if start_to is not None:
            query = query.where(Event.start_at <= start_to)

        query = query.order_by(Event.start_at.asc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def create(self, user_id: uuid.UUID, event_data: EventCreate) -> Event:
        event = Event(
            user_id=user_id,
            title=event_data.title,
            description=event_data.description,
            start_at=event_data.start_at,
            end_at=event_data.end_at,
            all_day=event_data.all_day,
            type=event_data.type,
            location=event_data.location,
            is_fixed=event_data.is_fixed,
            source=event_data.source,
        )
        self.db.add(event)
        await self.db.commit()
        await self.db.refresh(event)
        return event

    async def update(self, event_id: uuid.UUID, user_id: uuid.UUID, event_data: EventUpdate) -> Optional[Event]:
        event = await self.get_by_id(event_id, user_id)
        if not event:
            return None
        for field, value in event_data.model_dump(exclude_unset=True).items():
            setattr(event, field, value)
        await self.db.commit()
        await self.db.refresh(event)
        return event

    async def delete(self, event_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        result = await self.db.execute(
            delete(Event).where(Event.id == event_id, Event.user_id == user_id)
        )
        await self.db.commit()
        return result.rowcount > 0

    async def get_events_for_days(
        self,
        user_id: uuid.UUID,
        day_ranges: list[tuple[datetime, datetime]],
    ) -> List[Event]:
        """Return events whose start_at falls within any of the given UTC day ranges."""
        if not day_ranges:
            return []
        conditions = [
            and_(Event.start_at >= start, Event.start_at < end)
            for start, end in day_ranges
        ]
        query = (
            select(Event)
            .where(Event.user_id == user_id)
            .where(or_(*conditions))
            .order_by(Event.start_at.asc())
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def sync_batch(
        self,
        user_id: uuid.UUID,
        upserts: list[EventSyncUpsert],
        delete_ids: list[uuid.UUID],
    ) -> tuple[list[Event], list[Event], list[Event]]:
        created: list[Event] = []
        updated: list[Event] = []

        ids_to_check = [u.id for u in upserts if u.id is not None]
        existing_map: dict[uuid.UUID, Event] = {}
        if ids_to_check:
            result = await self.db.execute(
                select(Event).where(Event.id.in_(ids_to_check), Event.user_id == user_id)
            )
            for event in result.scalars().all():
                existing_map[event.id] = event

        for upsert in upserts:
            if upsert.id and upsert.id in existing_map:
                event = existing_map[upsert.id]
                event.title = upsert.title
                event.description = upsert.description
                event.start_at = upsert.start_at
                event.end_at = upsert.end_at
                event.all_day = upsert.all_day
                event.type = upsert.type
                event.location = upsert.location
                event.is_fixed = upsert.is_fixed
                updated.append(event)
            else:
                # Ignore provided id to avoid PK conflicts with other users' events.
                event = Event(
                    id=uuid.uuid4(),
                    user_id=user_id,
                    title=upsert.title,
                    description=upsert.description,
                    start_at=upsert.start_at,
                    end_at=upsert.end_at,
                    all_day=upsert.all_day,
                    type=upsert.type,
                    location=upsert.location,
                    is_fixed=upsert.is_fixed,
                    source=upsert.source,
                )
                self.db.add(event)
                created.append(event)

        deleted_events: list[Event] = []
        if delete_ids:
            result = await self.db.execute(
                select(Event).where(Event.id.in_(delete_ids), Event.user_id == user_id)
            )
            deleted_events = list(result.scalars().all())
            await self.db.execute(
                delete(Event).where(Event.id.in_(delete_ids), Event.user_id == user_id)
            )

        await self.db.commit()

        for event in created + updated:
            await self.db.refresh(event)

        return created, updated, deleted_events

    async def bulk_update_times(
        self,
        user_id: uuid.UUID,
        changes: list[dict],
    ) -> None:
        """Update start_at/end_at for multiple events belonging to the user."""
        for change in changes:
            event = await self.get_by_id(change["id"], user_id)
            if event:
                event.start_at = change["start_at"]
                event.end_at = change.get("end_at")
        await self.db.commit()
