from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.base import get_db
from app.infrastructure.database.repositories import UserRepository
from app.core.schemas.user import UserCreate, UserLogin, Token, User
from app.core.security import verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Регистрация нового пользователя
    
    - **email**: уникальный email пользователя
    - **password**: пароль (минимум 8 символов)
    """
    user_repo = UserRepository(db)
    
    # Проверяем, существует ли пользователь с таким email
    existing_user = await user_repo.get_by_email(user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Создаем нового пользователя
    user = await user_repo.create(user_data)
    return user


@router.post("/login", response_model=Token)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    """
    Вход пользователя и получение JWT токена
    
    - **email**: email пользователя
    - **password**: пароль
    
    Returns:
        JWT токен для аутентификации
    """
    user_repo = UserRepository(db)
    
    # Получаем пользователя по email
    user = await user_repo.get_by_email(credentials.email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Проверяем пароль
    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Обновляем время последнего входа
    await user_repo.update_last_login(user.id)
    
    # Создаем JWT токен
    access_token = create_access_token(data={"sub": str(user.id)})
    
    return Token(access_token=access_token)