import uuid
from datetime import datetime
from sqlalchemy import String, Integer, DateTime, ForeignKey, func, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
import enum


class MeetingStatus(str, enum.Enum):
    recording = "recording"
    uploaded = "uploaded"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class Meeting(Base):
    __tablename__ = "meetings"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    title: Mapped[str] = mapped_column(String(255), default="Untitled Meeting")
    status: Mapped[MeetingStatus] = mapped_column(
        Enum(MeetingStatus), default=MeetingStatus.uploaded
    )

    # Audio file
    audio_filename: Mapped[str | None] = mapped_column(String(512), nullable=True)
    audio_size_bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Timestamps
    recorded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self):
        return f"<Meeting {self.id} [{self.status}]>"
