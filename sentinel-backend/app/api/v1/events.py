import logging
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.schemas.event import Event, EventCreate, EventUpdate, EventList
from app.core.services.achievement_service import AchievementService
from app.infrastructure.database.base import get_db
from app.infrastructure.database.models import User
from app.infrastructure.database.repositories import EventRepository
from app.infrastructure.database.repositories.idempotency_repository import IdempotencyRepository

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/events", tags=["Events"])


@router.get("/", response_model=EventList)
async def get_events(
    date_from: Optional[datetime] = Query(None, description="Начало диапазона (ISO-8601)"),
    date_to: Optional[datetime] = Query(None, description="Конец диапазона (ISO-8601)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Получить события пользователя.

    - Без параметров — все предстоящие события (от текущего момента).
    - **date_from** / **date_to** — произвольный диапазон по start_at события.
    """
    if date_from and date_to and date_to <= date_from:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_to must be after date_from",
        )

    event_repo = EventRepository(db)
    items = await event_repo.search(current_user.id, start_from=date_from, start_to=date_to)
    return EventList(items=items, total=len(items))


@router.post("/", response_model=Event, status_code=status.HTTP_201_CREATED)
async def create_event(
    event_data: EventCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    x_idempotency_key: Optional[str] = Header(None),
):
    idempotency_repo = IdempotencyRepository(db)

    if x_idempotency_key:
        existing = await idempotency_repo.get(x_idempotency_key, current_user.id)
        if existing:
            event = await EventRepository(db).get_by_id(existing.event_id, current_user.id)
            if event:
                logger.info(
                    "idempotency_hit user_id=%s key=%s event_id=%s",
                    current_user.id, x_idempotency_key, event.id,
                )
                return JSONResponse(content=jsonable_encoder(event), status_code=200)

    event_repo = EventRepository(db)
    event = await event_repo.create(current_user.id, event_data)

    if x_idempotency_key:
        await idempotency_repo.save(x_idempotency_key, current_user.id, event.id)
        await db.commit()

    logger.info(
        "event_created user_id=%s event_id=%s source=%s type=%s",
        current_user.id, event.id, event.source, event.type,
    )

    await AchievementService(db).handle_event_created(
        current_user.id, {"source": event.source, "type": event.type}
    )
    return event


@router.get("/{event_id}", response_model=Event)
async def get_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event_repo = EventRepository(db)
    event = await event_repo.get_by_id(event_id, current_user.id)
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return event


@router.patch("/{event_id}", response_model=Event)
async def update_event(
    event_id: uuid.UUID,
    event_data: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event_repo = EventRepository(db)
    event = await event_repo.update(event_id, current_user.id, event_data)
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    logger.info("event_updated user_id=%s event_id=%s", current_user.id, event.id)
    return event


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event_repo = EventRepository(db)
    event = await event_repo.get_by_id(event_id, current_user.id)
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    await event_repo.delete(event_id, current_user.id)
    logger.info(
        "event_deleted user_id=%s event_id=%s source=%s type=%s",
        current_user.id, event_id, event.source, event.type,
    )
    await AchievementService(db).handle_event_deleted(
        current_user.id, {"source": event.source, "type": event.type}
    )
