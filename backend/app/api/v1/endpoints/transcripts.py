from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.meeting import Meeting
from app.models.transcript import TranscriptSegment
from app.schemas.transcript import TranscriptResponse, TranscriptSegmentResponse
from fastapi import HTTPException

router = APIRouter()


@router.get("/{meeting_id}", response_model=TranscriptResponse)
async def get_transcript(
    meeting_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify meeting belongs to user
    meeting_result = await db.execute(
        select(Meeting).where(
            Meeting.id == meeting_id,
            Meeting.user_id == current_user.id
        )
    )
    meeting = meeting_result.scalar_one_or_none()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")

    # Get segments ordered by index
    result = await db.execute(
        select(TranscriptSegment)
        .where(TranscriptSegment.meeting_id == meeting_id)
        .order_by(TranscriptSegment.segment_index)
    )
    segments = list(result.scalars().all())

    total_duration = segments[-1].end_time if segments else 0.0

    return TranscriptResponse(
        meeting_id=meeting_id,
        segments=[TranscriptSegmentResponse.model_validate(s) for s in segments],
        total_duration=total_duration,
        segment_count=len(segments),
    )