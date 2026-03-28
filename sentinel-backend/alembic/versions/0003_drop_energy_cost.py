"""drop energy_cost from events

Revision ID: 0003dropenergycost
Revises: 0002chats
Create Date: 2026-03-28

"""
from alembic import op
import sqlalchemy as sa

revision = "0003dropenergycost"
down_revision = "0002chats"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("events", "energy_cost")


def downgrade() -> None:
    op.add_column(
        "events",
        sa.Column("energy_cost", sa.Integer(), nullable=False, server_default="0"),
    )
