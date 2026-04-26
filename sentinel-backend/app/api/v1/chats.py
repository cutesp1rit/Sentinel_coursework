from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import uuid

from app.infrastructure.database.base import get_db
from app.infrastructure.database.repositories.chat_repository import ChatRepository, ChatMessageRepository
from app.infrastructure.database.repositories.event_repository import EventRepository
from app.infrastructure.external.openai_client import get_llm_client
from app.infrastructure.database.models import User
from app.core.config import settings
from app.core.schemas.chat import (
    Chat, ChatCreate, ChatList,
    ChatMessage, ChatMessageCreate, ChatMessageList,
    EventActionsContent, ImageAttachment, ImageMessageContent, UploadResponse,
    ApplyActionsRequest,
)
from app.core.services.llm_service import LLMService
from app.core.services.achievement_service import AchievementService
from app.core.services.storage_service import upload_image
from app.api.dependencies import get_current_user
from app.core.limiter import limiter

router = APIRouter(prefix="/chats", tags=["Chats"])

IMAGE_ONLY_VISION_DISABLED_REPLY = (
    "Я сохранил изображение. Добавьте текстовый запрос, и я помогу без распознавания картинок."
)


@router.get("/", response_model=ChatList)
async def get_chats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Список чатов текущего пользователя, отсортированных по последнему сообщению."""
    repo = ChatRepository(db)
    items = await repo.get_user_chats(current_user.id)
    return ChatList(items=items, total=len(items))


@router.post("/", response_model=Chat, status_code=status.HTTP_201_CREATED)
async def create_chat(
    data: ChatCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Создать новую чат-сессию."""
    repo = ChatRepository(db)
    return await repo.create(current_user.id, data)


@router.get("/{chat_id}/messages", response_model=ChatMessageList)
async def get_messages(
    chat_id: uuid.UUID,
    limit: int = Query(100, ge=1, le=200, description="Количество сообщений"),
    before: Optional[uuid.UUID] = Query(None, description="ID сообщения — вернуть сообщения старше него"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    История сообщений чата. Сортировка: старые → новые.

    - Без параметров — последние 100 сообщений.
    - **before** — ID самого старого из уже загруженных сообщений;
      вернёт следующую порцию ещё более старых (для подгрузки при скролле вверх).
    - **has_more** — если True, есть ещё более старые сообщения.
    """
    chat_repo = ChatRepository(db)
    chat = await chat_repo.get_by_id(chat_id, current_user.id)
    if not chat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")

    msg_repo = ChatMessageRepository(db)
    items, has_more = await msg_repo.get_messages(chat_id, limit=limit, before=before)
    return ChatMessageList(items=items, has_more=has_more)


@router.delete("/{chat_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_chat(
    chat_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Удалить чат вместе со всеми сообщениями."""
    repo = ChatRepository(db)
    deleted = await repo.delete(chat_id, current_user.id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")


@router.post("/{chat_id}/upload", response_model=UploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_chat_image(
    chat_id: uuid.UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Загрузить изображение для отправки в чат. Возвращает URL для последующей отправки в сообщении."""
    chat_repo = ChatRepository(db)
    if not await chat_repo.get_by_id(chat_id, current_user.id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")

    ext = file.filename.rsplit(".", 1)[-1].lower() if file.filename and "." in file.filename else ""
    if ext not in settings.ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type not allowed. Allowed: {', '.join(settings.ALLOWED_IMAGE_EXTENSIONS)}",
        )

    file_bytes = await file.read()
    if len(file_bytes) > settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size: {settings.MAX_FILE_SIZE // (1024 * 1024)} MB",
        )

    try:
        url = await upload_image(file_bytes, file.filename or "image", file.content_type, chat_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage service unavailable",
        )

    return UploadResponse(url=url, filename=file.filename or "image", mime_type=file.content_type or "image/jpeg")


@router.post("/{chat_id}/messages", response_model=ChatMessage, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def create_message(
    request: Request,
    chat_id: uuid.UUID,
    data: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Отправить сообщение в чат.

    Если role == "user" — сохраняет сообщение, вызывает LLM и возвращает ответ ассистента.
    """
    chat_repo = ChatRepository(db)
    chat = await chat_repo.get_by_id(chat_id, current_user.id)
    if not chat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")

    msg_repo = ChatMessageRepository(db)

    if data.role != "user":
        return await msg_repo.create(chat_id, data)

    # Загружаем историю до сохранения нового сообщения
    history = await msg_repo.get_recent_for_llm(chat_id, limit=settings.LLM_HISTORY_LIMIT)

    # Если пришли изображения — упаковываем их в content_structured
    user_msg_data = data
    if data.images:
        user_msg_data = ChatMessageCreate(
            role=data.role,
            content_text=data.content_text,
            content_structured=ImageMessageContent(images=data.images),
            ai_model=data.ai_model,
        )

    await msg_repo.create(chat_id, user_msg_data)

    if data.images and not settings.LLM_VISION_ENABLED and not (data.content_text or "").strip():
        assistant_data = ChatMessageCreate(
            role="assistant",
            content_text=IMAGE_ONLY_VISION_DISABLED_REPLY,
            ai_model=None,
        )
        return await msg_repo.create(chat_id, assistant_data)

    images_for_llm = (
        [img.model_dump() for img in data.images]
        if data.images else None
    )

    try:
        llm = LLMService(get_llm_client())
        text, actions = await llm.process_user_message(
            user_message=data.content_text or "",
            history=history,
            user_id=current_user.id,
            user_timezone=current_user.timezone,
            event_repo=EventRepository(db),
            images=images_for_llm,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="LLM service unavailable",
        )

    content_structured = EventActionsContent(actions=actions) if actions else None
    assistant_data = ChatMessageCreate(
        role="assistant",
        content_text=text or None,
        content_structured=content_structured,
        ai_model=settings.LLM_MODEL,
    )
    return await msg_repo.create(chat_id, assistant_data)


@router.post("/{chat_id}/messages/{message_id}/apply", response_model=ChatMessage)
async def apply_actions(
    chat_id: uuid.UUID,
    message_id: uuid.UUID,
    data: ApplyActionsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Применить выбранные действия из сообщения ассистента.

    Принимает список индексов действий которые пользователь подтвердил.
    Остальные помечаются как rejected. Применённые действия (create/update/delete)
    выполняются над таблицей events.
    """
    chat_repo = ChatRepository(db)
    chat = await chat_repo.get_by_id(chat_id, current_user.id)
    if not chat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")

    msg_repo = ChatMessageRepository(db)
    message = await msg_repo.get_by_id(message_id, chat_id)
    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    if (
        not message.content_structured
        or message.content_structured.get("type") != "event_actions"
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message does not contain event actions",
        )

    content = EventActionsContent.model_validate(message.content_structured)

    for idx in data.accepted_indices:
        if idx < 0 or idx >= len(content.actions):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid action index: {idx}",
            )

    event_repo = EventRepository(db)
    achievement_service = AchievementService(db)

    for idx, action in enumerate(content.actions):
        if idx in data.accepted_indices:
            if action.action == "create":
                created = await event_repo.create(current_user.id, action.payload)
                await achievement_service.handle_event_created(
                    current_user.id, {"source": created.source, "type": created.type}
                )
            elif action.action == "update":
                await event_repo.update(action.event_id, current_user.id, action.payload)
            elif action.action == "delete":
                event = await event_repo.get_by_id(action.event_id, current_user.id)
                await event_repo.delete(action.event_id, current_user.id)
                if event:
                    await achievement_service.handle_event_deleted(
                        current_user.id, {"source": event.source, "type": event.type}
                    )
            action.status = "accepted"
        else:
            action.status = "rejected"

    return await msg_repo.update_structured(
        message_id, chat_id, content.model_dump(mode="json")
    )
