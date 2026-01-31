from sqlalchemy import Column, String, DateTime, Boolean, Text, ForeignKey, TIMESTAMP, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.infrastructure.database.base import Base


class Event(Base):
    """Модель события календаря"""
    __tablename__ = "events"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Event details
    title = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Time
    start_at = Column(TIMESTAMP(timezone=True), nullable=False, index=True)
    end_at = Column(TIMESTAMP(timezone=True))  # NULL для напоминаний
    all_day = Column(Boolean, default=False, nullable=False)
    
    # Type and metadata
    type = Column(String(20), nullable=False, default="event")  # event или reminder
    location = Column(String(255))
    source = Column(String(20), default="user")  # user, ai, import
    
    # Resource Battery & Rebalance
    energy_cost = Column(Integer, default=0)  # Энергозатраты: -50 (восстановление) до +50 (затраты)
    is_fixed = Column(Boolean, default=False, nullable=False)  # Зафиксировано для перебалансировки
    
    # Timestamps
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="events")
    
    def __repr__(self):
        return f"<Event {self.title} at {self.start_at}>"