from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
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


class ChatMessageRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_messages(self, chat_id: uuid.UUID) -> List[ChatMessage]:
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat_id)
            .order_by(ChatMessage.created_at.asc())
        )
        return list(result.scalars().all())

    async def get_by_id(self, message_id: uuid.UUID, chat_id: uuid.UUID) -> Optional[ChatMessage]:
        result = await self.db.execute(
            select(ChatMessage).where(
                ChatMessage.id == message_id,
                ChatMessage.chat_id == chat_id,
            )
        )
        return result.scalar_one_or_none()

    async def count(self, chat_id: uuid.UUID) -> int:
        result = await self.db.execute(
            select(func.count(ChatMessage.id)).where(ChatMessage.chat_id == chat_id)
        )
        return result.scalar_one()

    async def create(self, chat_id: uuid.UUID, data: ChatMessageCreate) -> ChatMessage:
        # Сериализуем Pydantic-объект в dict для JSONB
        structured = (
            data.content_structured.model_dump(mode="json")
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
