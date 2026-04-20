"""email verification and password reset tokens

Revision ID: 0006emailauthtokens
Revises: 0005idempotencykeys
Create Date: 2026-04-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0006emailauthtokens"
down_revision = "0005idempotencykeys"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default="false"),
    )

    op.create_table(
        "auth_tokens",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token", sa.String(255), nullable=False, unique=True),
        sa.Column("token_type", sa.String(50), nullable=False),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_auth_tokens_token", "auth_tokens", ["token"], unique=True)
    op.create_index("ix_auth_tokens_user_id_type", "auth_tokens", ["user_id", "token_type"])


def downgrade() -> None:
    op.drop_index("ix_auth_tokens_user_id_type", table_name="auth_tokens")
    op.drop_index("ix_auth_tokens_token", table_name="auth_tokens")
    op.drop_table("auth_tokens")
    op.drop_column("users", "is_verified")
