import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class RebalanceDay(BaseModel):
    date: date
    resource_battery: Optional[float] = Field(None, ge=0.0, le=1.0)


class RebalanceRequest(BaseModel):
    timezone: str
    days: list[RebalanceDay] = Field(..., min_length=1)
    user_prompt: Optional[str] = Field(None, max_length=500)


class ProposedEvent(BaseModel):
    id: uuid.UUID
    title: str
    start_at: datetime
    end_at: Optional[datetime]
    original_start_at: datetime
    original_end_at: Optional[datetime]
    changed: bool

    class Config:
        from_attributes = True


class RebalanceResponse(BaseModel):
    proposed: list[ProposedEvent]
    summary: str
    changed_count: int
    unchanged_count: int


class ApplyEventChange(BaseModel):
    id: uuid.UUID
    start_at: datetime
    end_at: Optional[datetime] = None


class RebalanceApplyRequest(BaseModel):
    events: list[ApplyEventChange] = Field(..., min_length=1)
