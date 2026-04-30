"""add ai_instructions to users

Revision ID: 0007useraiinstructions
Revises: 0006emailauthtokens
Create Date: 2026-04-26
"""

from alembic import op
import sqlalchemy as sa

revision = "0007useraiinstructions"
down_revision = "0006emailauthtokens"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("ai_instructions", sa.String(500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "ai_instructions")
