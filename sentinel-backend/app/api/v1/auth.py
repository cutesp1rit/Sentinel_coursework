import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.config import settings
from app.core.schemas.user import (
    DeleteAccountRequest,
    ForgotPasswordRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    Token,
    UpdateProfileRequest,
    User,
    UserCreate,
    UserLogin,
    VerifyEmailRequest,
)
from app.core.security import create_access_token, get_password_hash, verify_password
from app.core.services.email_service import send_password_reset_email, send_verification_email
from app.infrastructure.database.base import get_db
from app.infrastructure.database.models import User as UserModel
from app.infrastructure.database.models.auth_token import EMAIL_VERIFICATION, PASSWORD_RESET
from app.infrastructure.database.repositories import UserRepository
from app.infrastructure.database.repositories.auth_token_repository import AuthTokenRepository

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user_repo = UserRepository(db)
    if await user_repo.get_by_email(user_data.email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )
    user = await user_repo.create(user_data)

    if settings.REQUIRE_EMAIL_VERIFICATION:
        token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.EMAIL_VERIFICATION_EXPIRE_HOURS)
        token_repo = AuthTokenRepository(db)
        await token_repo.create(user.id, token, EMAIL_VERIFICATION, expires_at)
        await db.commit()
        background_tasks.add_task(send_verification_email, user.email, token)
    else:
        await user_repo.set_verified(user.id)
        await db.commit()
        await db.refresh(user)

    return user


@router.post("/login", response_model=Token)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db),
):
    user_repo = UserRepository(db)
    user = await user_repo.get_by_email(credentials.email)
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    if settings.REQUIRE_EMAIL_VERIFICATION and not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified. Check your inbox or request a new verification email.",
        )
    await user_repo.update_last_login(user.id)
    access_token = create_access_token(data={"sub": str(user.id)})
    return Token(access_token=access_token)


@router.post("/verify-email")
async def verify_email(
    request: VerifyEmailRequest,
    db: AsyncSession = Depends(get_db),
):
    token_repo = AuthTokenRepository(db)
    auth_token = await token_repo.get_by_token(request.token, EMAIL_VERIFICATION)

    if not auth_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired token",
        )
    if auth_token.expires_at < datetime.now(timezone.utc):
        await token_repo.delete_by_id(auth_token.id)
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token expired",
        )

    user_repo = UserRepository(db)
    await user_repo.set_verified(auth_token.user_id)
    await token_repo.delete_by_id(auth_token.id)
    await db.commit()
    return {"message": "Email verified successfully"}


@router.post("/resend-verification")
async def resend_verification(
    request: ResendVerificationRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user_repo = UserRepository(db)
    user = await user_repo.get_by_email(request.email)

    if user and user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already verified",
        )

    if user:
        token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.EMAIL_VERIFICATION_EXPIRE_HOURS)
        token_repo = AuthTokenRepository(db)
        await token_repo.create(user.id, token, EMAIL_VERIFICATION, expires_at)
        await db.commit()
        background_tasks.add_task(send_verification_email, user.email, token)

    return {"message": "If this email is registered and unverified, a new verification email has been sent"}


@router.post("/forgot-password")
async def forgot_password(
    request: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user_repo = UserRepository(db)
    user = await user_repo.get_by_email(request.email)

    if user:
        token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.PASSWORD_RESET_EXPIRE_HOURS)
        token_repo = AuthTokenRepository(db)
        await token_repo.create(user.id, token, PASSWORD_RESET, expires_at)
        await db.commit()
        background_tasks.add_task(send_password_reset_email, user.email, token)

    # Always 200 to prevent email enumeration
    return {"message": "If this email is registered, a password reset link has been sent"}


@router.post("/reset-password")
async def reset_password(
    request: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    token_repo = AuthTokenRepository(db)
    auth_token = await token_repo.get_by_token(request.token, PASSWORD_RESET)

    if not auth_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired token",
        )
    if auth_token.expires_at < datetime.now(timezone.utc):
        await token_repo.delete_by_id(auth_token.id)
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token expired",
        )

    user_repo = UserRepository(db)
    await user_repo.update_password(auth_token.user_id, get_password_hash(request.new_password))
    await token_repo.delete_by_id(auth_token.id)
    await db.commit()
    return {"message": "Password reset successfully"}


@router.get("/me", response_model=User)
async def get_me(current_user: UserModel = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=User)
async def update_me(
    data: UpdateProfileRequest,
    current_user: UserModel = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_repo = UserRepository(db)
    return await user_repo.update_profile(current_user.id, data)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    request: DeleteAccountRequest,
    current_user: UserModel = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(request.password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect password",
        )
    user_repo = UserRepository(db)
    await user_repo.delete(current_user)
    await db.commit()
