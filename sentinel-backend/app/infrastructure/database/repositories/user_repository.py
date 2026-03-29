from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
import uuid

from app.infrastructure.database.models import User
from app.core.schemas.user import UserCreate
from app.core.security import get_password_hash


class UserRepository:
    """Репозиторий для работы с пользователями"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_by_id(self, user_id: uuid.UUID) -> Optional[User]:
        """Получить пользователя по ID"""
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()
    
    async def get_by_email(self, email: str) -> Optional[User]:
        """Получить пользователя по email"""
        result = await self.db.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()
    
    async def create(self, user_data: UserCreate) -> User:
        """Создать нового пользователя"""
        user = User(
            email=user_data.email,
            password_hash=get_password_hash(user_data.password),
            timezone=user_data.timezone,
        )
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        return user
    
    async def update_last_login(self, user_id: uuid.UUID) -> None:
        """Обновить время последнего входа"""
        from sqlalchemy import update
        from datetime import datetime
        
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(last_login=datetime.utcnow())
        )
        await self.db.commit()