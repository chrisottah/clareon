import os
import uuid
import aiofiles
from datetime import datetime, timezone
from fastapi import UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.meeting import Meeting, MeetingStatus
from app.core.config import settings


async def create_meeting_from_upload(
    db: AsyncSession,
    user_id: str,
    audio_file: UploadFile,
    title: str,
    duration_seconds: int | None,
    recorded_at: datetime | None,
) -> Meeting:
    """Save uploaded audio file and create meeting record."""

    # Validate file type
    allowed_types = {"audio/m4a", "audio/mp4", "audio/mpeg", "audio/wav",
                     "audio/aac", "audio/x-m4a", "application/octet-stream"}
    content_type = audio_file.content_type or "application/octet-stream"
    if content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format: {content_type}",
        )

    # Build storage path: media/{user_id}/{meeting_id}.m4a
    meeting_id = str(uuid.uuid4())
    user_dir = os.path.join(settings.MEDIA_DIR, user_id)
    os.makedirs(user_dir, exist_ok=True)

    filename = f"{meeting_id}.m4a"
    file_path = os.path.join(user_dir, filename)

    # Stream file to disk
    file_size = 0
    async with aiofiles.open(file_path, "wb") as f:
        while chunk := await audio_file.read(1024 * 1024):  # 1MB chunks
            await f.write(chunk)
            file_size += len(chunk)

    # Validate file isn't empty
    if file_size == 0:
        os.remove(file_path)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty",
        )

    meeting = Meeting(
        id=meeting_id,
        user_id=user_id,
        title=title or "Untitled Meeting",
        status=MeetingStatus.uploaded,
        audio_filename=filename,
        audio_size_bytes=file_size,
        duration_seconds=duration_seconds,
        recorded_at=recorded_at or datetime.now(timezone.utc),
    )
    db.add(meeting)
    await db.commit()
    await db.refresh(meeting)
    return meeting


async def get_user_meetings(db: AsyncSession, user_id: str) -> list[Meeting]:
    result = await db.execute(
        select(Meeting)
        .where(Meeting.user_id == user_id)
        .order_by(Meeting.created_at.desc())
    )
    return list(result.scalars().all())


async def get_meeting(db: AsyncSession, meeting_id: str, user_id: str) -> Meeting:
    result = await db.execute(
        select(Meeting).where(Meeting.id == meeting_id, Meeting.user_id == user_id)
    )
    meeting = result.scalar_one_or_none()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return meeting
