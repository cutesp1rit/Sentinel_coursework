from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
import uuid

from app.infrastructure.database.models import Event
from app.infrastructure.database.models.achievement import UserCounter


class CounterRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def increment(self, user_id: uuid.UUID, counter_name: str, delta: int = 1) -> None:
        stmt = (
            pg_insert(UserCounter)
            .values(id=uuid.uuid4(), user_id=user_id, counter_name=counter_name, value=max(0, delta))
            .on_conflict_do_update(
                constraint="uq_user_counter",
                set_={"value": func.greatest(0, UserCounter.value + delta)},
            )
        )
        await self.db.execute(stmt)

    async def set_counter(self, user_id: uuid.UUID, counter_name: str, value: int) -> None:
        stmt = (
            pg_insert(UserCounter)
            .values(id=uuid.uuid4(), user_id=user_id, counter_name=counter_name, value=value)
            .on_conflict_do_update(
                constraint="uq_user_counter",
                set_={"value": value},
            )
        )
        await self.db.execute(stmt)

    async def get_all(self, user_id: uuid.UUID) -> dict[str, int]:
        result = await self.db.execute(
            select(UserCounter).where(UserCounter.user_id == user_id)
        )
        return {c.counter_name: c.value for c in result.scalars().all()}

    async def recompute_active_days(self, user_id: uuid.UUID) -> int:
        subq = (
            select(func.date_trunc("day", Event.start_at))
            .where(Event.user_id == user_id)
            .distinct()
            .subquery()
        )
        result = await self.db.execute(select(func.count()).select_from(subq))
        count = result.scalar() or 0
        await self.set_counter(user_id, "active_days", count)
        return count
