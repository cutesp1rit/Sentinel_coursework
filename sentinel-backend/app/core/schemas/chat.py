from pydantic import BaseModel, Field, model_validator
from typing import Annotated, Literal, Optional, Any, Union
from datetime import datetime
import uuid

from app.core.schemas.event import EventCreate, EventUpdate


class ImageAttachment(BaseModel):
    url: str
    filename: str
    mime_type: str


class ImageMessageContent(BaseModel):
    type: Literal["image_message"] = "image_message"
    images: list[ImageAttachment]


class UploadResponse(BaseModel):
    url: str
    filename: str
    mime_type: str


class EventSnapshot(BaseModel):
    title: str
    start_at: datetime
    end_at: Optional[datetime] = None


class EventAction(BaseModel):
    action: Literal["create", "update", "delete"]
    event_id: Optional[uuid.UUID] = None
    payload: Optional[EventCreate | EventUpdate] = None
    status: Literal["pending", "accepted", "rejected"] = "pending"
    event_snapshot: Optional[EventSnapshot] = None

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
    type: Literal["event_actions"] = "event_actions"
    actions: list[EventAction]


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


StructuredContent = Annotated[
    Union[EventActionsContent, ImageMessageContent],
    Field(discriminator="type"),
]


class ChatMessageCreate(BaseModel):
    role: Literal["user", "assistant", "tool", "system"]
    content_text: Optional[str] = None
    content_structured: Optional[StructuredContent] = None
    images: Optional[list[ImageAttachment]] = None
    ai_model: Optional[str] = None


class ChatMessage(BaseModel):
    id: uuid.UUID
    chat_id: uuid.UUID
    role: str
    content_text: Optional[str]
    content_structured: Optional[dict[str, Any]]
    ai_model: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ChatMessageList(BaseModel):
    items: list[ChatMessage]  # oldest to newest
    has_more: bool            # True if older messages exist


class ApplyActionsRequest(BaseModel):
    accepted_indices: list[int]
