from pydantic import BaseModel
from datetime import datetime
from typing import Optional
import uuid


class AchievementLevel(BaseModel):
    id: uuid.UUID
    level: int
    title: str
    description: str
    icon: str
    target_value: int
    unlocked: bool
    earned_at: Optional[datetime]

    model_config = {"from_attributes": True}


class AchievementGroup(BaseModel):
    group_code: str
    category: str
    counter_name: str
    current_value: int
    levels: list[AchievementLevel]


class AchievementsResponse(BaseModel):
    groups: list[AchievementGroup]


