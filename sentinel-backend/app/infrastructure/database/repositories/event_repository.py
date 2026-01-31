from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from typing import Optional, List
import uuid

from app.infrastructure.database.models import Event
from app.core.schemas.event import EventCreate, EventUpdate


class EventRepository:
    """Репозиторий для работы с событиями"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_by_id(self, event_id: uuid.UUID, user_id: uuid.UUID) -> Optional[Event]:
        """Получить событие по ID (с проверкой владельца)"""
        result = await self.db.execute(
            select(Event).where(
                Event.id == event_id,
                Event.user_id == user_id
            )
        )
        return result.scalar_one_or_none()
    
    async def get_user_events(self, user_id: uuid.UUID, skip: int = 0, limit: int = 100) -> List[Event]:
        """Получить список событий пользователя"""
        result = await self.db.execute(
            select(Event)
            .where(Event.user_id == user_id)
            .order_by(Event.start_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())
    
    async def count_user_events(self, user_id: uuid.UUID) -> int:
        """Подсчитать количество событий пользователя"""
        from sqlalchemy import func
        result = await self.db.execute(
            select(func.count(Event.id)).where(Event.user_id == user_id)
        )
        return result.scalar_one()
    
    async def create(self, user_id: uuid.UUID, event_data: EventCreate) -> Event:
        """Создать новое событие"""
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
            source="user"  # По умолчанию создано пользователем
        )
        self.db.add(event)
        await self.db.commit()
        await self.db.refresh(event)
        return event
    
    async def update(self, event_id: uuid.UUID, user_id: uuid.UUID, event_data: EventUpdate) -> Optional[Event]:
        """Обновить событие"""
        event = await self.get_by_id(event_id, user_id)
        if not event:
            return None
        
        # Обновляем только переданные поля
        update_data = event_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(event, field, value)
        
        await self.db.commit()
        await self.db.refresh(event)
        return event
    
    async def delete(self, event_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        """Удалить событие"""
        result = await self.db.execute(
            delete(Event).where(
                Event.id == event_id,
                Event.user_id == user_id
            )
        )
        await self.db.commit()
        return result.rowcount > 0