from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
import uuid


class UserBase(BaseModel):
    """Базовая схема пользователя"""
    email: EmailStr


class UserCreate(UserBase):
    """Схема для создания пользователя"""
    password: str = Field(..., min_length=8, description="Пароль (минимум 8 символов)")


class UserLogin(BaseModel):
    """Схема для входа пользователя"""
    email: EmailStr
    password: str


class User(UserBase):
    """Схема пользователя для ответа"""
    id: uuid.UUID
    timezone: str
    locale: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class Token(BaseModel):
    """Схема токена доступа"""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Данные из токена"""
    user_id: Optional[uuid.UUID] = None