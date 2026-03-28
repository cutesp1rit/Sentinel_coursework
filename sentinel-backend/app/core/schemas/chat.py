from pydantic import BaseModel, Field
from typing import Literal, Optional, Any
from datetime import datetime
import uuid

from app.core.schemas.event import EventCreate


class EventSuggestionsContent(BaseModel):
    """Структурированный контент сообщения — список предложений событий от модели."""
    type: Literal["event_suggestions"] = "event_suggestions"
    events: list[EventCreate]


class ChatCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)


class Chat(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    title: str
    last_message_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ChatList(BaseModel):
    items: list[Chat]
    total: int


class ChatMessageCreate(BaseModel):
    role: Literal["user", "assistant", "tool", "system"]
    content_text: Optional[str] = None
    content_structured: Optional[EventSuggestionsContent] = None
    ai_model: Optional[str] = None


class ChatMessage(BaseModel):
    id: uuid.UUID
    chat_id: uuid.UUID
    role: str
    content_text: Optional[str]
    content_structured: Optional[dict[str, Any]]  # читаем как dict — приходит из JSONB
    ai_model: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ChatMessageList(BaseModel):
    items: list[ChatMessage]
    total: int
