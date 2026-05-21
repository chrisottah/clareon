from pydantic import BaseModel
from typing import Optional


class TranscriptSegmentResponse(BaseModel):
    id: str
    meeting_id: str
    start_time: float
    end_time: float
    text: str
    speaker: Optional[str] = None
    confidence: Optional[float] = None
    segment_index: int

    model_config = {"from_attributes": True}


class TranscriptResponse(BaseModel):
    meeting_id: str
    segments: list[TranscriptSegmentResponse]
    total_duration: float
    segment_count: int