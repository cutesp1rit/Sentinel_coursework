from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
import uuid

from app.infrastructure.database.models.achievement import Achievement, UserAchievement


class AchievementRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_all(self) -> list[Achievement]:
        result = await self.db.execute(
            select(Achievement).order_by(Achievement.group_code, Achievement.level)
        )
        return list(result.scalars().all())

    async def get_by_counter_names(self, counter_names: set[str]) -> list[Achievement]:
        result = await self.db.execute(
            select(Achievement).where(Achievement.counter_name.in_(counter_names))
        )
        return list(result.scalars().all())

    async def has_achievement(self, user_id: uuid.UUID, achievement_id: uuid.UUID) -> bool:
        result = await self.db.execute(
            select(func.count()).where(
                UserAchievement.user_id == user_id,
                UserAchievement.achievement_id == achievement_id,
            )
        )
        return (result.scalar() or 0) > 0

    async def award(
        self, user_id: uuid.UUID, achievement_id: uuid.UUID
    ) -> Optional[UserAchievement]:
        if await self.has_achievement(user_id, achievement_id):
            return None
        ua = UserAchievement(user_id=user_id, achievement_id=achievement_id)
        self.db.add(ua)
        await self.db.flush()
        await self.db.refresh(ua)
        return ua

    async def get_user_achievements(self, user_id: uuid.UUID) -> dict[uuid.UUID, UserAchievement]:
        result = await self.db.execute(
            select(UserAchievement).where(UserAchievement.user_id == user_id)
        )
        return {ua.achievement_id: ua for ua in result.scalars().all()}
