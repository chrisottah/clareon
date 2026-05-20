from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from app.models.meeting import MeetingStatus


class MeetingResponse(BaseModel):
    id: str
    user_id: str
    title: str
    status: MeetingStatus
    audio_filename: Optional[str] = None
    audio_size_bytes: Optional[int] = None
    duration_seconds: Optional[int] = None
    recorded_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MeetingUploadResponse(BaseModel):
    meeting_id: str
    message: str
    status: MeetingStatus
