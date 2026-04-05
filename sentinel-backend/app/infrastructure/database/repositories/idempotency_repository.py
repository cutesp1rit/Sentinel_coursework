import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import select, delete
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.models.idempotency import IdempotencyKey

TTL_HOURS = 24


class IdempotencyRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get(self, key: str, user_id: uuid.UUID) -> Optional[IdempotencyKey]:
        now = datetime.now(timezone.utc)
        result = await self.db.execute(
            select(IdempotencyKey).where(
                IdempotencyKey.key == key,
                IdempotencyKey.user_id == user_id,
                IdempotencyKey.expires_at > now,
            )
        )
        return result.scalar_one_or_none()

    async def save(self, key: str, user_id: uuid.UUID, event_id: uuid.UUID) -> None:
        expires_at = datetime.now(timezone.utc) + timedelta(hours=TTL_HOURS)
        stmt = pg_insert(IdempotencyKey).values(
            id=uuid.uuid4(),
            key=key,
            user_id=user_id,
            event_id=event_id,
            expires_at=expires_at,
        ).on_conflict_do_nothing(constraint="uq_idempotency_key_user")
        await self.db.execute(stmt)

    async def cleanup_expired(self) -> None:
        now = datetime.now(timezone.utc)
        await self.db.execute(
            delete(IdempotencyKey).where(IdempotencyKey.expires_at <= now)
        )
