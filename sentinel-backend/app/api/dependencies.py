from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import uuid

from app.infrastructure.database.base import get_db
from app.infrastructure.database.repositories import UserRepository
from app.infrastructure.database.models import User
from app.core.security import decode_access_token

# HTTP Bearer схема для JWT
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Получить текущего аутентифицированного пользователя
    
    Raises:
        HTTPException: 401 если токен невалидный или пользователь не найден
    """
    token = credentials.credentials
    
    # Декодируем токен и получаем user_id
    user_id = decode_access_token(token)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Получаем пользователя из БД
    user_repo = UserRepository(db)
    user = await user_repo.get_by_id(user_id)
    
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user