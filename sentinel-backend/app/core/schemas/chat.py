from pydantic import BaseModel, Field, model_validator
from typing import Literal, Optional, Any
from datetime import datetime
import uuid

from app.core.schemas.event import EventCreate, EventUpdate


# ─── Structured content ───────────────────────────────────────────────────────

class EventAction(BaseModel):
    """Одно предлагаемое действие над событием."""
    action: Literal["create", "update", "delete"]
    event_id: Optional[uuid.UUID] = None   # обязателен для update/delete
    payload: Optional[EventCreate | EventUpdate] = None  # данные для create/update
    status: Literal["pending", "accepted", "rejected"] = "pending"

    @model_validator(mode="after")
    def check_fields(self) -> "EventAction":
        if self.action == "create" and self.payload is None:
            raise ValueError("payload required for action='create'")
        if self.action == "update" and (self.event_id is None or self.payload is None):
            raise ValueError("event_id and payload required for action='update'")
        if self.action == "delete" and self.event_id is None:
            raise ValueError("event_id required for action='delete'")
        return self


class EventActionsContent(BaseModel):
    """content_structured сообщения ассистента с предложениями действий."""
    type: Literal["event_actions"] = "event_actions"
    actions: list[EventAction]


# ─── Chat ─────────────────────────────────────────────────────────────────────

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


# ─── Chat messages ────────────────────────────────────────────────────────────

class ChatMessageCreate(BaseModel):
    role: Literal["user", "assistant", "tool", "system"]
    content_text: Optional[str] = None
    content_structured: Optional[EventActionsContent] = None
    ai_model: Optional[str] = None


class ChatMessage(BaseModel):
    id: uuid.UUID
    chat_id: uuid.UUID
    role: str
    content_text: Optional[str]
    content_structured: Optional[dict[str, Any]]  # читаем как dict из JSONB
    ai_model: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ChatMessageList(BaseModel):
    items: list[ChatMessage]
    total: int


# ─── Apply actions ────────────────────────────────────────────────────────────

class ApplyActionsRequest(BaseModel):
    """Индексы действий из списка, которые пользователь хочет применить."""
    accepted_indices: list[int]
