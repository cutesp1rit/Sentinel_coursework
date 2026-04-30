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

from sqlalchemy import delete, select, func
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.config import settings
from app.core.security import get_password_hash
from app.infrastructure.database.models import User, Event
from app.infrastructure.database.models.achievement import Achievement, UserAchievement, UserCounter
import uuid

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
                is_verified=True,
            )
            db.add(user)
            await db.flush()
        else:
            user.password_hash = get_password_hash(TEST_PASSWORD)
            user.timezone = TEST_TIMEZONE
            user.is_verified = True

        await db.execute(delete(Event).where(Event.user_id == user.id))
        await db.execute(delete(UserAchievement).where(UserAchievement.user_id == user.id))
        await db.execute(delete(UserCounter).where(UserCounter.user_id == user.id))

        # Build fresh event list
        events = [
            Event(
                user_id=user.id,
                title="Team meeting",
                description="Q2 roadmap discussion",
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
                title="Submit report",
                description="Quarterly project report",
                start_at=_dt(tz, days=-5, hour=18),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Alexey's birthday",
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
                description="Review PR #42 — new auth module",
                start_at=_dt(tz, days=-2, hour=15),
                end_at=_dt(tz, days=-2, hour=16),
                type="event",
                all_day=False,
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Client call",
                start_at=_dt(tz, days=-1, hour=11),
                end_at=_dt(tz, days=-1, hour=11, minute=30),
                type="event",
                all_day=False,
                location="Google Meet",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Morning workout",
                start_at=_dt(tz, days=0, hour=7, minute=30),
                end_at=_dt(tz, days=0, hour=8, minute=30),
                type="event",
                all_day=False,
                location="Gym",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Standup",
                description="Daily team sync",
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
                title="Lunch with Maria",
                start_at=_dt(tz, days=0, hour=13),
                end_at=_dt(tz, days=0, hour=14),
                type="event",
                all_day=False,
                location="Central Cafe",
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Write unit tests for events module",
                start_at=_dt(tz, days=0, hour=15),
                end_at=_dt(tz, days=0, hour=17),
                type="event",
                all_day=False,
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Buy groceries",
                start_at=_dt(tz, days=0, hour=19),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Deadline: submit coursework",
                start_at=_dt(tz, days=2, hour=23, minute=59),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Candidate interview",
                description="Junior Python Developer, technical interview",
                start_at=_dt(tz, days=2, hour=14),
                end_at=_dt(tz, days=2, hour=15),
                type="event",
                all_day=False,
                location="Office, meeting room 2",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Sprint planning",
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
                title="Haircut",
                start_at=_dt(tz, days=4, hour=18),
                end_at=_dt(tz, days=4, hour=18, minute=40),
                type="event",
                all_day=False,
                location="Barbershop on Arbat",
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Team party",
                description="End of quarter — celebrating results",
                start_at=_dt(tz, days=5, hour=19),
                end_at=_dt(tz, days=5, hour=23),
                type="event",
                all_day=False,
                location="Restaurant Moscow",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Online course: ML lecture",
                start_at=_dt(tz, days=8, hour=19),
                end_at=_dt(tz, days=8, hour=21),
                type="event",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Stakeholder demo",
                description="Presenting Sentinel MVP",
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
                title="Pay rent",
                start_at=_dt(tz, days=10, hour=12),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            # Day +12 is heavily overloaded; days +13 and +14 are mostly free.
            # Select all three days and run Rebalance to see it redistribute.
            Event(
                user_id=user.id,
                title="Standup (fixed)",
                description="Daily sync, do not reschedule",
                start_at=_dt(tz, days=12, hour=9),
                end_at=_dt(tz, days=12, hour=9, minute=30),
                type="event",
                all_day=False,
                location="Zoom",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Write technical specification",
                description="Detailed spec for the new notifications module",
                start_at=_dt(tz, days=12, hour=10),
                end_at=_dt(tz, days=12, hour=12),
                type="event",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Team code review",
                description="Check 4 open PRs before end of day",
                start_at=_dt(tz, days=12, hour=13),
                end_at=_dt(tz, days=12, hour=14),
                type="event",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Fix critical bug",
                description="Auth bug — P0 priority",
                start_at=_dt(tz, days=12, hour=14),
                end_at=_dt(tz, days=12, hour=15, minute=30),
                type="event",
                all_day=False,
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Write unit tests",
                description="Cover the new rebalance service with tests",
                start_at=_dt(tz, days=12, hour=15, minute=30),
                end_at=_dt(tz, days=12, hour=17),
                type="event",
                all_day=False,
                source="ai",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Refactor events module",
                description="Extract business logic from router into service",
                start_at=_dt(tz, days=12, hour=17),
                end_at=_dt(tz, days=12, hour=18, minute=30),
                type="event",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Check email",
                start_at=_dt(tz, days=13, hour=10),
                end_at=None,
                type="reminder",
                all_day=False,
                source="user",
                is_fixed=False,
            ),
            Event(
                user_id=user.id,
                title="Mentor call (fixed)",
                description="Weekly 1:1, do not reschedule",
                start_at=_dt(tz, days=14, hour=11),
                end_at=_dt(tz, days=14, hour=11, minute=45),
                type="event",
                all_day=False,
                location="Zoom",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="Vacation",
                start_at=_dt(tz, days=30, hour=0),
                end_at=_dt(tz, days=37, hour=0),
                type="event",
                all_day=True,
                location="Turkey",
                source="user",
                is_fixed=True,
            ),
            Event(
                user_id=user.id,
                title="PyCon Russia conference",
                start_at=_dt(tz, days=45, hour=9),
                end_at=_dt(tz, days=46, hour=18),
                type="event",
                all_day=False,
                location="Moscow, Expocentre",
                source="user",
                is_fixed=False,
            ),
        ]

        db.add_all(events)
        await db.flush()

        # Compute counters from seeded events
        total_events = len(events)
        ai_events = sum(1 for e in events if e.source == "ai")
        total_reminders = sum(1 for e in events if e.type == "reminder")

        subq = (
            select(func.date_trunc("day", Event.start_at))
            .where(Event.user_id == user.id)
            .distinct()
            .subquery()
        )
        result = await db.execute(select(func.count()).select_from(subq))
        active_days = result.scalar() or 0

        counters = [
            {"counter_name": "total_events", "value": total_events},
            {"counter_name": "ai_events", "value": ai_events},
            {"counter_name": "total_reminders", "value": total_reminders},
            {"counter_name": "active_days", "value": active_days},
        ]
        for c in counters:
            stmt = (
                pg_insert(UserCounter)
                .values(id=uuid.uuid4(), user_id=user.id, **c)
                .on_conflict_do_update(
                    constraint="uq_user_counter",
                    set_={"value": c["value"]},
                )
            )
            await db.execute(stmt)

        # Award achievements based on computed counters
        counter_map = {c["counter_name"]: c["value"] for c in counters}
        achievements_result = await db.execute(select(Achievement))
        for achievement in achievements_result.scalars().all():
            if counter_map.get(achievement.counter_name, 0) >= achievement.target_value:
                await db.execute(
                    pg_insert(UserAchievement)
                    .values(id=uuid.uuid4(), user_id=user.id, achievement_id=achievement.id)
                    .on_conflict_do_nothing(constraint="uq_user_achievement")
                )

        await db.commit()

    print(
        f"[seed] Test account ready: {TEST_EMAIL} / {TEST_PASSWORD} "
        f"({len(events)} events, {active_days} active days)"
    )


if __name__ == "__main__":
    asyncio.run(seed())
