"""
Seed script for the test account.

Runs on every container start after migrations.
Resets the test user's events to a known state without touching other data.

Test account credentials:
  email:    test@sentinel.dev
  password: Sentinel123!
  timezone: Europe/Moscow
"""

import asyncio
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.security import get_password_hash
from app.infrastructure.database.models import User, Event

TEST_EMAIL = "test@sentinel.dev"
TEST_PASSWORD = "Sentinel123!"
TEST_TIMEZONE = "Europe/Moscow"

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


def _dt(tz: ZoneInfo, days: int = 0, hour: int = 9, minute: int = 0) -> datetime:
    base = datetime.now(tz).replace(hour=hour, minute=minute, second=0, microsecond=0)
    return base + timedelta(days=days)


async def seed() -> None:
    tz = ZoneInfo(TEST_TIMEZONE)

    async with AsyncSessionLocal() as db:
        # Upsert test user
        result = await db.execute(select(User).where(User.email == TEST_EMAIL))
        user = result.scalar_one_or_none()
        if user is None:
            user = User(
                email=TEST_EMAIL,
                password_hash=get_password_hash(TEST_PASSWORD),
                timezone=TEST_TIMEZONE,
            )
            db.add(user)
            await db.flush()
        else:
            user.password_hash = get_password_hash(TEST_PASSWORD)
            user.timezone = TEST_TIMEZONE

        # Drop all existing events for the test user
        await db.execute(delete(Event).where(Event.user_id == user.id))

        # Build fresh event list
        events = [
            # ── Past ──────────────────────────────────────────────
            Event(
                user_id=user.id,
                title="Встреча с командой",
                description="Обсуждение roadmap на Q2",
                start_at=_dt(tz, days=-7, hour=10),
                end_at=_dt(tz, days=-7, hour=11),
                type="event",
                all_day=False,
                location="Zoom",
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Сдать отчёт",
                description="Квартальный отчёт по проекту",
                start_at=_dt(tz, days=-5, hour=18),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="День рождения Алексея",
                start_at=_dt(tz, days=-3, hour=0),
                end_at=None,
                type="event",
                all_day=True,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Code review",
                description="Ревью PR #42 — новый модуль авторизации",
                start_at=_dt(tz, days=-2, hour=15),
                end_at=_dt(tz, days=-2, hour=16),
                type="event",
                all_day=False,
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Звонок с заказчиком",
                start_at=_dt(tz, days=-1, hour=11),
                end_at=_dt(tz, days=-1, hour=11, minute=30),
                type="event",
                all_day=False,
                location="Google Meet",
                source="user",
                is_fixed=True,
            ),
            # ── Today ─────────────────────────────────────────────
            Event(
                user_id=user.id,
                title="Утренняя тренировка",
                start_at=_dt(tz, days=0, hour=7, minute=30),
                end_at=_dt(tz, days=0, hour=8, minute=30),
                type="event",
                all_day=False,
                location="Спортзал",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Стендап",
                description="Ежедневный синк команды",
                start_at=_dt(tz, days=0, hour=10),
                end_at=_dt(tz, days=0, hour=10, minute=15),
                type="event",
                all_day=False,
                location="Zoom",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Обед с Марией",
                start_at=_dt(tz, days=0, hour=13),
                end_at=_dt(tz, days=0, hour=14),
                type="event",
                all_day=False,
                location="Кафе «Центральное»",
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Написать unit-тесты для модуля событий",
                start_at=_dt(tz, days=0, hour=15),
                end_at=_dt(tz, days=0, hour=17),
                type="event",
                all_day=False,
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Купить продукты",
                start_at=_dt(tz, days=0, hour=19),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            # ── This week ─────────────────────────────────────────
            Event(
                user_id=user.id,
                title="Дедлайн: сдать курсовую",
                start_at=_dt(tz, days=2, hour=23, minute=59),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Интервью с кандидатом",
                description="Junior Python Developer, техническое интервью",
                start_at=_dt(tz, days=2, hour=14),
                end_at=_dt(tz, days=2, hour=15),
                type="event",
                all_day=False,
                location="Офис, переговорная №2",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Планирование спринта",
                start_at=_dt(tz, days=3, hour=10),
                end_at=_dt(tz, days=3, hour=12),
                type="event",
                all_day=False,
                location="Zoom",
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Стрижка",
                start_at=_dt(tz, days=4, hour=18),
                end_at=_dt(tz, days=4, hour=18, minute=40),
                type="event",
                all_day=False,
                location="Барбершоп на Арбате",
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Корпоратив",
                description="Конец квартала — отмечаем результаты",
                start_at=_dt(tz, days=5, hour=19),
                end_at=_dt(tz, days=5, hour=23),
                type="event",
                all_day=False,
                location="Ресторан «Москва»",
                source="user",
                is_fixed=True,
            ),
            # ── Next week ─────────────────────────────────────────
            Event(
                user_id=user.id,
                title="Онлайн-курс: лекция по ML",
                start_at=_dt(tz, days=8, hour=19),
                end_at=_dt(tz, days=8, hour=21),
                type="event",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Демо для стейкхолдеров",
                description="Показываем Sentinel MVP",
                start_at=_dt(tz, days=9, hour=16),
                end_at=_dt(tz, days=9, hour=17),
                type="event",
                all_day=False,
                location="Zoom",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Оплатить аренду",
                start_at=_dt(tz, days=10, hour=12),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            # ── Far future ────────────────────────────────────────
            Event(
                user_id=user.id,
                title="Отпуск",
                start_at=_dt(tz, days=30, hour=0),
                end_at=_dt(tz, days=37, hour=0),
                type="event",
                all_day=True,
                location="Турция",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Конференция PyCon Russia",
                start_at=_dt(tz, days=45, hour=9),
                end_at=_dt(tz, days=46, hour=18),
                type="event",
                all_day=False,
                location="Москва, Экспоцентр",
                source="user",
                is_fixed=False,
            ),
        ]

        db.add_all(events)
        await db.commit()

    print(f"[seed] Test account ready: {TEST_EMAIL} / {TEST_PASSWORD} ({len(events)} events)")


if __name__ == "__main__":
    asyncio.run(seed())
