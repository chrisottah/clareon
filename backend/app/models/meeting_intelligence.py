import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, func, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


class MeetingIntelligence(Base):
    __tablename__ = "meeting_intelligence"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    meeting_id: Mapped[str] = mapped_column(
        String, ForeignKey("meetings.id", ondelete="CASCADE"),
        nullable=False, unique=True, index=True
    )

    # AI outputs
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    action_points: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON string
    key_insights: Mapped[str | None] = mapped_column(Text, nullable=True)   # JSON string

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    def __repr__(self):
        return f"<MeetingIntelligence {self.meeting_id}>"