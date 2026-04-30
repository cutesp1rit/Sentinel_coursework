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
        Cursor-based pagination. Returns (messages, has_more).
        messages are sorted oldest to newest; has_more indicates older pages exist.
        """
        query = select(ChatMessage).where(ChatMessage.chat_id == chat_id)

        if before is not None:
            ref = await self.db.execute(
                select(ChatMessage.created_at).where(ChatMessage.id == before)
            )
            ref_ts = ref.scalar_one_or_none()
            if ref_ts is not None:
                query = query.where(ChatMessage.created_at < ref_ts)

        # fetch limit+1 to detect if more messages exist
        query = query.order_by(ChatMessage.created_at.desc()).limit(limit + 1)
        result = await self.db.execute(query)
        rows = list(result.scalars().all())

        has_more = len(rows) > limit
        if has_more:
            rows = rows[:limit]

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
        # serialize to dict for JSONB storage
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

        chat_result = await self.db.execute(select(Chat).where(Chat.id == chat_id))
        chat = chat_result.scalar_one_or_none()
        if chat:
            chat.last_message_at = datetime.now(timezone.utc)

        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def get_recent_for_llm(self, chat_id: uuid.UUID, limit: int) -> list[dict]:
        """Return the last N messages formatted for the LLM. Image messages are expanded to multimodal content arrays."""
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat_id)
            .where(ChatMessage.role.in_(["user", "assistant"]))
            .order_by(ChatMessage.created_at.desc())
            .limit(limit)
        )
        messages = list(result.scalars().all())
        messages.reverse()

        history = []
        for m in messages:
            if (
                m.role == "user"
                and m.content_structured
                and m.content_structured.get("type") == "image_message"
            ):
                content: list[dict] = []
                if m.content_text:
                    content.append({"type": "text", "text": m.content_text})
                for img in m.content_structured.get("images", []):
                    content.append({"type": "image_url", "image_url": {"url": img["url"]}})
                history.append({"role": "user", "content": content})
            elif (
                m.role == "assistant"
                and m.content_structured
                and m.content_structured.get("type") == "event_actions"
            ):
                # Convert actions to plain statements so the LLM understands outcomes
                # without treating them as open proposals.
                parts = [m.content_text] if m.content_text else []
                actions = m.content_structured.get("actions", [])
                for a in actions:
                    status = a.get("status", "pending")
                    op = a["action"]
                    if op == "create":
                        payload = a.get("payload", {})
                        title = payload.get("title", "?")
                        start = payload.get("start_at", "?")
                        if status == "accepted":
                            parts.append(f"'{title}' at {start} was saved to the calendar.")
                        elif status == "rejected":
                            parts.append(f"'{title}' at {start} was proposed but the user declined it.")
                        else:
                            parts.append(f"'{title}' at {start} was proposed, awaiting user confirmation.")
                    elif op == "update":
                        eid = a.get("event_id", "?")
                        if status == "accepted":
                            parts.append(f"Event {eid} was updated and saved.")
                        elif status == "rejected":
                            parts.append(f"Update for event {eid} was proposed but the user declined it.")
                        else:
                            parts.append(f"Update for event {eid} was proposed, awaiting user confirmation.")
                    elif op == "delete":
                        eid = a.get("event_id", "?")
                        if status == "accepted":
                            parts.append(f"Event {eid} was deleted.")
                        elif status == "rejected":
                            parts.append(f"Deletion of event {eid} was proposed but the user declined it.")
                        else:
                            parts.append(f"Deletion of event {eid} was proposed, awaiting user confirmation.")
                history.append({"role": "assistant", "content": "\n".join(parts)})
            else:
                history.append({"role": m.role, "content": m.content_text or ""})

        return history

    async def update_structured(
        self,
        message_id: uuid.UUID,
        chat_id: uuid.UUID,
        content_structured: dict,
    ) -> Optional[ChatMessage]:
        """Update content_structured of a message (action statuses after apply)."""
        message = await self.get_by_id(message_id, chat_id)
        if not message:
            return None
        message.content_structured = content_structured
        await self.db.commit()
        await self.db.refresh(message)
        return message
