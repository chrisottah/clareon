from fastapi import APIRouter, Depends, UploadFile, File, Form, status
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime
from typing import Optional

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.meeting import MeetingResponse, MeetingUploadResponse
from app.services import meeting_service

router = APIRouter()


@router.post("/upload", response_model=MeetingUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_meeting(
    audio: UploadFile = File(..., description="Audio recording file"),
    title: str = Form(default="Untitled Meeting"),
    duration_seconds: Optional[int] = Form(default=None),
    recorded_at: Optional[datetime] = Form(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a recorded meeting audio file."""
    meeting = await meeting_service.create_meeting_from_upload(
        db=db,
        user_id=current_user.id,
        audio_file=audio,
        title=title,
        duration_seconds=duration_seconds,
        recorded_at=recorded_at,
    )
    return MeetingUploadResponse(
        meeting_id=meeting.id,
        message="Upload successful. Processing will begin shortly.",
        status=meeting.status,
    )


@router.get("/", response_model=list[MeetingResponse])
async def list_meetings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all meetings for the current user."""
    return await meeting_service.get_user_meetings(db, current_user.id)


@router.get("/{meeting_id}", response_model=MeetingResponse)
async def get_meeting(
    meeting_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single meeting by ID."""
    return await meeting_service.get_meeting(db, meeting_id, current_user.id)
