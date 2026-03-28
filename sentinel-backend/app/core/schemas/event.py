from pydantic import BaseModel, Field, model_validator
from typing import Literal, Optional
from datetime import datetime
import uuid


class EventBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    start_at: datetime = Field(..., description="ISO-8601")
    end_at: Optional[datetime] = Field(None, description="NULL для напоминаний")
    all_day: bool = False
    type: Literal["event", "reminder"] = "event"
    location: Optional[str] = Field(None, max_length=255)
    is_fixed: bool = False

    @model_validator(mode="after")
    def end_after_start(self) -> "EventBase":
        if self.end_at is not None and self.end_at <= self.start_at:
            raise ValueError("end_at must be after start_at")
        return self


class EventCreate(EventBase):
    source: Literal["user", "ai", "import"] = "user"


class EventUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    all_day: Optional[bool] = None
    type: Optional[Literal["event", "reminder"]] = None
    location: Optional[str] = Field(None, max_length=255)
    is_fixed: Optional[bool] = None


class Event(EventBase):
    id: uuid.UUID
    user_id: uuid.UUID
    source: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class EventList(BaseModel):
    items: list[Event]
    total: int