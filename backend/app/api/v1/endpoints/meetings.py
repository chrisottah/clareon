import os
from fastapi import APIRouter, Depends, UploadFile, File, Form, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete as sql_delete
from datetime import datetime
from typing import Optional
from pydantic import BaseModel

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.meeting import MeetingResponse, MeetingUploadResponse
from app.services import meeting_service
from app.core.config import settings
from app.tasks.process_meeting import process_meeting_task

router = APIRouter()


class UpdateTitleRequest(BaseModel):
    title: str


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
    process_meeting_task.delay(str(meeting.id))
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


@router.patch("/{meeting_id}", response_model=MeetingResponse)
async def update_meeting_title(
    meeting_id: str,
    data: UpdateTitleRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update meeting title."""
    meeting = await meeting_service.get_meeting(db, meeting_id, current_user.id)
    meeting.title = data.title
    await db.commit()
    await db.refresh(meeting)
    return meeting


@router.delete("/{meeting_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meeting(
    meeting_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a meeting and its audio file."""
    meeting = await meeting_service.get_meeting(db, meeting_id, current_user.id)

    # Delete audio file from disk
    if meeting.audio_filename:
        audio_path = os.path.join(
            settings.MEDIA_DIR, current_user.id, meeting.audio_filename
        )
        if os.path.exists(audio_path):
            os.remove(audio_path)

    await db.delete(meeting)
    await db.commit()