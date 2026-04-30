from sqlalchemy import Column, String, Boolean, Text, ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.infrastructure.database.base import Base


class Event(Base):
    __tablename__ = "events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    description = Column(Text)

    start_at = Column(TIMESTAMP(timezone=True), nullable=False, index=True)
    end_at = Column(TIMESTAMP(timezone=True))  # NULL for reminders
    all_day = Column(Boolean, default=False, nullable=False)

    type = Column(String(20), nullable=False, default="event")  # event or reminder
    location = Column(String(255))
    source = Column(String(20), default="user")  # user, ai, import

    is_fixed = Column(Boolean, default=False, nullable=False)

    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User", back_populates="events")

    def __repr__(self):
        return f"<Event {self.title} at {self.start_at}>"
