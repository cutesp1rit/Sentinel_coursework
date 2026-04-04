"""achievements

Revision ID: 0004achievements
Revises: 0003dropenergycost
Create Date: 2026-04-04

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
import uuid

revision = "0004achievements"
down_revision = "0003dropenergycost"
branch_labels = None
depends_on = None

SEED_ACHIEVEMENTS = [
    # events_created
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000001")),
        "group_code": "events_created",
        "level": 1,
        "title": "First Step",
        "description": "Created your first event",
        "icon": "🗓️",
        "category": "milestones",
        "counter_name": "total_events",
        "target_value": 1,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000002")),
        "group_code": "events_created",
        "level": 2,
        "title": "Planner",
        "description": "Created 10 events",
        "icon": "📋",
        "category": "milestones",
        "counter_name": "total_events",
        "target_value": 10,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000003")),
        "group_code": "events_created",
        "level": 3,
        "title": "Power Planner",
        "description": "Created 50 events",
        "icon": "🏆",
        "category": "milestones",
        "counter_name": "total_events",
        "target_value": 50,
    },
    # ai_assisted
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000004")),
        "group_code": "ai_assisted",
        "level": 1,
        "title": "AI Explorer",
        "description": "Created first event with AI",
        "icon": "🤖",
        "category": "ai",
        "counter_name": "ai_events",
        "target_value": 1,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000005")),
        "group_code": "ai_assisted",
        "level": 2,
        "title": "AI Collaborator",
        "description": "Created 10 events with AI",
        "icon": "⚡",
        "category": "ai",
        "counter_name": "ai_events",
        "target_value": 10,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000006")),
        "group_code": "ai_assisted",
        "level": 3,
        "title": "AI Master",
        "description": "Created 25 events with AI",
        "icon": "🧠",
        "category": "ai",
        "counter_name": "ai_events",
        "target_value": 25,
    },
    # reminders
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000007")),
        "group_code": "reminders",
        "level": 1,
        "title": "Don't Forget",
        "description": "Created first reminder",
        "icon": "🔔",
        "category": "habits",
        "counter_name": "total_reminders",
        "target_value": 1,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000008")),
        "group_code": "reminders",
        "level": 2,
        "title": "Reminder Fan",
        "description": "Created 5 reminders",
        "icon": "📌",
        "category": "habits",
        "counter_name": "total_reminders",
        "target_value": 5,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000009")),
        "group_code": "reminders",
        "level": 3,
        "title": "Reminder Pro",
        "description": "Created 20 reminders",
        "icon": "✅",
        "category": "habits",
        "counter_name": "total_reminders",
        "target_value": 20,
    },
    # active_days
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000010")),
        "group_code": "active_days",
        "level": 1,
        "title": "Getting Started",
        "description": "Planned events on 3 different days",
        "icon": "📅",
        "category": "habits",
        "counter_name": "active_days",
        "target_value": 3,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000011")),
        "group_code": "active_days",
        "level": 2,
        "title": "Consistent",
        "description": "Planned events on 7 different days",
        "icon": "🔥",
        "category": "habits",
        "counter_name": "active_days",
        "target_value": 7,
    },
    {
        "id": str(uuid.UUID("00000000-0000-0000-0000-000000000012")),
        "group_code": "active_days",
        "level": 3,
        "title": "Dedicated",
        "description": "Planned events on 30 different days",
        "icon": "💪",
        "category": "habits",
        "counter_name": "active_days",
        "target_value": 30,
    },
]


def upgrade() -> None:
    op.create_table(
        "achievements",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("group_code", sa.String(50), nullable=False),
        sa.Column("level", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("icon", sa.String(50), nullable=False),
        sa.Column("category", sa.String(50), nullable=False),
        sa.Column("counter_name", sa.String(50), nullable=False),
        sa.Column("target_value", sa.Integer(), nullable=False),
        sa.UniqueConstraint("group_code", "level", name="uq_achievement_group_level"),
    )
    op.create_index("ix_achievements_group_code", "achievements", ["group_code"])
    op.create_index("ix_achievements_counter_name", "achievements", ["counter_name"])

    op.create_table(
        "user_achievements",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("achievement_id", UUID(as_uuid=True), sa.ForeignKey("achievements.id", ondelete="CASCADE"), nullable=False),
        sa.Column("earned_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "achievement_id", name="uq_user_achievement"),
    )
    op.create_index("ix_user_achievements_user_id", "user_achievements", ["user_id"])

    op.create_table(
        "user_counters",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("counter_name", sa.String(50), nullable=False),
        sa.Column("value", sa.Integer(), nullable=False, server_default="0"),
        sa.UniqueConstraint("user_id", "counter_name", name="uq_user_counter"),
    )
    op.create_index("ix_user_counters_user_id", "user_counters", ["user_id"])

    achievements_table = sa.table(
        "achievements",
        sa.column("id", UUID(as_uuid=True)),
        sa.column("group_code", sa.String),
        sa.column("level", sa.Integer),
        sa.column("title", sa.String),
        sa.column("description", sa.Text),
        sa.column("icon", sa.String),
        sa.column("category", sa.String),
        sa.column("counter_name", sa.String),
        sa.column("target_value", sa.Integer),
    )
    op.bulk_insert(achievements_table, SEED_ACHIEVEMENTS)


def downgrade() -> None:
    op.drop_table("user_counters")
    op.drop_table("user_achievements")
    op.drop_table("achievements")
