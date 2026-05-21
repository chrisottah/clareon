from pydantic import BaseModel
from typing import Optional


class MeetingIntelligenceResponse(BaseModel):
    meeting_id: str
    summary: Optional[str] = None
    action_points: list[str] = []
    key_insights: list[str] = []

    model_config = {"from_attributes": True}