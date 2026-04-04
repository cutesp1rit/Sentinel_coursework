from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from collections import defaultdict

from app.infrastructure.database.base import get_db
from app.infrastructure.database.repositories.achievement_repository import AchievementRepository
from app.infrastructure.database.repositories.counter_repository import CounterRepository
from app.infrastructure.database.models import User
from app.core.schemas.achievement import AchievementsResponse, AchievementGroup, AchievementLevel
from app.api.dependencies import get_current_user

router = APIRouter(prefix="/achievements", tags=["Achievements"])


@router.get("/", response_model=AchievementsResponse)
async def get_achievements(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    achievement_repo = AchievementRepository(db)
    counter_repo = CounterRepository(db)

    all_achievements = await achievement_repo.get_all()
    counters = await counter_repo.get_all(current_user.id)
    unlocked = await achievement_repo.get_user_achievements(current_user.id)

    grouped: dict[str, list] = defaultdict(list)
    group_meta: dict[str, dict] = {}

    for achievement in all_achievements:
        ua = unlocked.get(achievement.id)
        grouped[achievement.group_code].append(
            AchievementLevel(
                id=achievement.id,
                level=achievement.level,
                title=achievement.title,
                description=achievement.description,
                icon=achievement.icon,
                target_value=achievement.target_value,
                unlocked=ua is not None,
                earned_at=ua.earned_at if ua else None,
            )
        )
        group_meta[achievement.group_code] = {
            "category": achievement.category,
            "counter_name": achievement.counter_name,
        }

    groups = [
        AchievementGroup(
            group_code=group_code,
            category=group_meta[group_code]["category"],
            counter_name=group_meta[group_code]["counter_name"],
            current_value=counters.get(group_meta[group_code]["counter_name"], 0),
            levels=levels,
        )
        for group_code, levels in grouped.items()
    ]

    return AchievementsResponse(groups=groups)
