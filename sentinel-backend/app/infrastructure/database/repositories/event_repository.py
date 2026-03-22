from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from typing import Optional, List
from datetime import datetime
import uuid

from app.infrastructure.database.models import Event
from app.core.schemas.event import EventCreate, EventUpdate


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
        """Поиск событий по диапазону дат."""
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
            energy_cost=event_data.energy_cost,
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
