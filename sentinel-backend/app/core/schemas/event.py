from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
import uuid


class EventBase(BaseModel):
    """Базовая схема события"""
    title: str = Field(..., min_length=1, max_length=255, description="Название события")
    description: Optional[str] = Field(None, description="Описание события")
    start_at: datetime = Field(..., description="Время начала в ISO-8601")
    end_at: Optional[datetime] = Field(None, description="Время окончания (NULL для напоминаний)")
    all_day: bool = Field(False, description="Событие на весь день")
    type: str = Field("event", description="Тип: event или reminder")
    location: Optional[str] = Field(None, max_length=255, description="Местоположение")
    energy_cost: int = Field(0, ge=-50, le=50, description="Энергозатраты от -50 до +50")
    is_fixed: bool = Field(False, description="Зафиксировано для перебалансировки")


class EventCreate(EventBase):
    """Схема для создания события"""
    pass


class EventUpdate(BaseModel):
    """Схема для обновления события"""
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    all_day: Optional[bool] = None
    type: Optional[str] = None
    location: Optional[str] = Field(None, max_length=255)
    energy_cost: Optional[int] = Field(None, ge=-50, le=50)
    is_fixed: Optional[bool] = None


class Event(EventBase):
    """Схема события для ответа"""
    id: uuid.UUID
    user_id: uuid.UUID
    source: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class EventList(BaseModel):
    """Схема списка событий"""
    items: list[Event]
    total: int