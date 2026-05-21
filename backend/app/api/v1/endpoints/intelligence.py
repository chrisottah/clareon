import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.meeting import Meeting
from app.models.meeting_intelligence import MeetingIntelligence
from app.schemas.intelligence import MeetingIntelligenceResponse

router = APIRouter()


@router.get("/{meeting_id}", response_model=MeetingIntelligenceResponse)
async def get_intelligence(
    meeting_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify meeting belongs to user
    meeting_result = await db.execute(
        select(Meeting).where(
            Meeting.id == meeting_id,
            Meeting.user_id == current_user.id,
        )
    )
    if not meeting_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Meeting not found")

    result = await db.execute(
        select(MeetingIntelligence).where(
            MeetingIntelligence.meeting_id == meeting_id
        )
    )
    intel = result.scalar_one_or_none()

    if not intel:
        raise HTTPException(
            status_code=404,
            detail="Intelligence not yet generated for this meeting",
        )

    return MeetingIntelligenceResponse(
        meeting_id=meeting_id,
        summary=intel.summary,
        action_points=json.loads(intel.action_points or "[]"),
        key_insights=json.loads(intel.key_insights or "[]"),
    )