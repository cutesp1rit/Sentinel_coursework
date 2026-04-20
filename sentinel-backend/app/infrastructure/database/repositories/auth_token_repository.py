from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from datetime import datetime
from typing import Optional
import uuid

from app.infrastructure.database.models.auth_token import AuthToken


class AuthTokenRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        user_id: uuid.UUID,
        token: str,
        token_type: str,
        expires_at: datetime,
    ) -> AuthToken:
        # Invalidate any existing token of the same type for this user
        await self.db.execute(
            delete(AuthToken).where(
                AuthToken.user_id == user_id,
                AuthToken.token_type == token_type,
            )
        )
        auth_token = AuthToken(
            user_id=user_id,
            token=token,
            token_type=token_type,
            expires_at=expires_at,
        )
        self.db.add(auth_token)
        await self.db.flush()
        return auth_token

    async def get_by_token(self, token: str, token_type: str) -> Optional[AuthToken]:
        result = await self.db.execute(
            select(AuthToken).where(
                AuthToken.token == token,
                AuthToken.token_type == token_type,
            )
        )
        return result.scalar_one_or_none()

    async def delete_by_id(self, token_id: uuid.UUID) -> None:
        await self.db.execute(
            delete(AuthToken).where(AuthToken.id == token_id)
        )
