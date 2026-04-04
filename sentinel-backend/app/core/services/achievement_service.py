from sqlalchemy.ext.asyncio import AsyncSession
import uuid

from app.infrastructure.database.models.achievement import UserAchievement
from app.infrastructure.database.repositories.achievement_repository import AchievementRepository
from app.infrastructure.database.repositories.counter_repository import CounterRepository


class AchievementService:

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = AchievementRepository(db)
        self.counter_repo = CounterRepository(db)

    async def handle_event_created(
        self, user_id: uuid.UUID, payload: dict
    ) -> list[UserAchievement]:
        updated_counters: set[str] = set()

        await self.counter_repo.increment(user_id, "total_events")
        updated_counters.add("total_events")

        if payload.get("source") == "ai":
            await self.counter_repo.increment(user_id, "ai_events")
            updated_counters.add("ai_events")

        if payload.get("type") == "reminder":
            await self.counter_repo.increment(user_id, "total_reminders")
            updated_counters.add("total_reminders")

        await self.counter_repo.recompute_active_days(user_id)
        updated_counters.add("active_days")

        await self.db.commit()
        return await self._check_and_award(user_id, updated_counters)

    async def handle_event_deleted(
        self, user_id: uuid.UUID, payload: dict
    ) -> None:
        await self.counter_repo.increment(user_id, "total_events", -1)

        if payload.get("source") == "ai":
            await self.counter_repo.increment(user_id, "ai_events", -1)

        if payload.get("type") == "reminder":
            await self.counter_repo.increment(user_id, "total_reminders", -1)

        await self.counter_repo.recompute_active_days(user_id)
        await self.db.commit()

    async def _check_and_award(
        self, user_id: uuid.UUID, updated_counter_names: set[str]
    ) -> list[UserAchievement]:
        counters = await self.counter_repo.get_all(user_id)
        achievements = await self.repo.get_by_counter_names(updated_counter_names)

        newly_awarded: list[UserAchievement] = []
        for achievement in achievements:
            if await self.repo.has_achievement(user_id, achievement.id):
                continue
            current = counters.get(achievement.counter_name, 0)
            if current >= achievement.target_value:
                ua = await self.repo.award(user_id, achievement.id)
                if ua:
                    newly_awarded.append(ua)

        if newly_awarded:
            await self.db.commit()

        return newly_awarded
