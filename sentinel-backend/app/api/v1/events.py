from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import uuid

from app.infrastructure.database.base import get_db
from app.infrastructure.database.repositories import EventRepository
from app.infrastructure.database.models import User
from app.core.schemas.event import Event, EventCreate, EventUpdate, EventList
from app.api.dependencies import get_current_user

router = APIRouter(prefix="/events", tags=["Events"])


@router.post("/", response_model=Event, status_code=status.HTTP_201_CREATED)
async def create_event(
    event_data: EventCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Создать новое событие
    
    - **title**: название события (обязательно)
    - **description**: описание события
    - **start_at**: время начала в ISO-8601 (обязательно)
    - **end_at**: время окончания (NULL для напоминаний)
    - **all_day**: событие на весь день
    - **type**: тип события (event или reminder)
    - **location**: местоположение
    - **energy_cost**: энергозатраты от -50 до +50
    - **is_fixed**: зафиксировано для перебалансировки
    """
    event_repo = EventRepository(db)
    event = await event_repo.create(current_user.id, event_data)
    return event


@router.get("/", response_model=EventList)
async def get_events(
    skip: int = Query(0, ge=0, description="Количество пропускаемых записей"),
    limit: int = Query(100, ge=1, le=1000, description="Максимальное количество записей"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Получить список событий текущего пользователя
    
    - **skip**: количество пропускаемых записей (для пагинации)
    - **limit**: максимальное количество записей (1-1000)
    """
    event_repo = EventRepository(db)
    events = await event_repo.get_user_events(current_user.id, skip, limit)
    total = await event_repo.count_user_events(current_user.id)
    
    return EventList(items=events, total=total)


@router.get("/{event_id}", response_model=Event)
async def get_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Получить событие по ID
    """
    event_repo = EventRepository(db)
    event = await event_repo.get_by_id(event_id, current_user.id)
    
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found"
        )
    
    return event


@router.patch("/{event_id}", response_model=Event)
async def update_event(
    event_id: uuid.UUID,
    event_data: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Обновить событие
    
    Можно обновить любые поля события. Передавайте только те поля, которые нужно изменить.
    """
    event_repo = EventRepository(db)
    event = await event_repo.update(event_id, current_user.id, event_data)
    
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found"
        )
    
    return event


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Удалить событие
    """
    event_repo = EventRepository(db)
    deleted = await event_repo.delete(event_id, current_user.id)
    
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found"
        )
    
    return None