from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional, List
from datetime import datetime, timezone
import uuid

from app.infrastructure.database.models.chat import Chat, ChatMessage
from app.core.schemas.chat import ChatCreate, ChatMessageCreate


class ChatRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_user_chats(self, user_id: uuid.UUID) -> List[Chat]:
        result = await self.db.execute(
            select(Chat)
            .where(Chat.user_id == user_id)
            .order_by(Chat.last_message_at.desc().nullslast(), Chat.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_by_id(self, chat_id: uuid.UUID, user_id: uuid.UUID) -> Optional[Chat]:
        result = await self.db.execute(
            select(Chat).where(Chat.id == chat_id, Chat.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def create(self, user_id: uuid.UUID, data: ChatCreate) -> Chat:
        chat = Chat(user_id=user_id, title=data.title)
        self.db.add(chat)
        await self.db.commit()
        await self.db.refresh(chat)
        return chat

    async def delete(self, chat_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        chat = await self.get_by_id(chat_id, user_id)
        if not chat:
            return False
        await self.db.delete(chat)
        await self.db.commit()
        return True


class ChatMessageRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_messages(
        self,
        chat_id: uuid.UUID,
        limit: int = 100,
        before: Optional[uuid.UUID] = None,
    ) -> tuple[List[ChatMessage], bool]:
        """
        Cursor-based пагинация сообщений чата.

        Возвращает (messages, has_more):
        - messages: список сообщений от старых к новым
        - has_more: True если есть ещё более старые сообщения
        """
        query = select(ChatMessage).where(ChatMessage.chat_id == chat_id)

        if before is not None:
            # Находим created_at курсорного сообщения и берём всё старше него
            ref = await self.db.execute(
                select(ChatMessage.created_at).where(ChatMessage.id == before)
            )
            ref_ts = ref.scalar_one_or_none()
            if ref_ts is not None:
                query = query.where(ChatMessage.created_at < ref_ts)

        # Запрашиваем limit+1 чтобы понять есть ли ещё сообщения
        query = query.order_by(ChatMessage.created_at.desc()).limit(limit + 1)
        result = await self.db.execute(query)
        rows = list(result.scalars().all())

        has_more = len(rows) > limit
        if has_more:
            rows = rows[:limit]

        # Разворачиваем в хронологический порядок (старые → новые)
        rows.reverse()
        return rows, has_more

    async def get_by_id(self, message_id: uuid.UUID, chat_id: uuid.UUID) -> Optional[ChatMessage]:
        result = await self.db.execute(
            select(ChatMessage).where(
                ChatMessage.id == message_id,
                ChatMessage.chat_id == chat_id,
            )
        )
        return result.scalar_one_or_none()

    async def create(self, chat_id: uuid.UUID, data: ChatMessageCreate) -> ChatMessage:
        # Сериализуем Pydantic-объект в dict для JSONB
        structured = (
            data.content_structured.model_dump(mode="json", exclude_none=True)
            if data.content_structured is not None
            else None
        )
        message = ChatMessage(
            chat_id=chat_id,
            role=data.role,
            content_text=data.content_text,
            content_structured=structured,
            ai_model=data.ai_model,
        )
        self.db.add(message)

        # Обновляем last_message_at у чата
        chat_result = await self.db.execute(select(Chat).where(Chat.id == chat_id))
        chat = chat_result.scalar_one_or_none()
        if chat:
            chat.last_message_at = datetime.now(timezone.utc)

        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def get_recent_for_llm(self, chat_id: uuid.UUID, limit: int) -> list[dict]:
        """Последние N сообщений чата в формате для передачи в LLM (role/content)."""
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat_id)
            .where(ChatMessage.role.in_(["user", "assistant"]))
            .order_by(ChatMessage.created_at.desc())
            .limit(limit)
        )
        messages = list(result.scalars().all())
        messages.reverse()
        return [{"role": m.role, "content": m.content_text or ""} for m in messages]

    async def update_structured(
        self,
        message_id: uuid.UUID,
        chat_id: uuid.UUID,
        content_structured: dict,
    ) -> Optional[ChatMessage]:
        """Обновить content_structured сообщения (статусы действий после apply)."""
        message = await self.get_by_id(message_id, chat_id)
        if not message:
            return None
        message.content_structured = content_structured
        await self.db.commit()
        await self.db.refresh(message)
        return message
