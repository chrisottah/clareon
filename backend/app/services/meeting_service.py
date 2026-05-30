import os
import uuid
import aiofiles
from datetime import datetime, timezone
from fastapi import UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.meeting import Meeting, MeetingStatus
from app.core.config import settings
from app.services.storage_service import upload_audio


async def create_meeting_from_upload(
    db: AsyncSession,
    user_id: str,
    audio_file: UploadFile,
    title: str,
    duration_seconds: int | None,
    recorded_at: datetime | None,
) -> Meeting:
    allowed_types = {"audio/m4a", "audio/mp4", "audio/mpeg", "audio/wav",
                     "audio/aac", "audio/x-m4a", "application/octet-stream"}
    content_type = audio_file.content_type or "application/octet-stream"
    if content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format: {content_type}",
        )

    meeting_id = str(uuid.uuid4())
    filename = f"{meeting_id}.m4a"

    # Save temporarily to disk first
    tmp_path = f"/tmp/{filename}"
    file_size = 0
    async with aiofiles.open(tmp_path, "wb") as f:
        while chunk := await audio_file.read(1024 * 1024):
            await f.write(chunk)
            file_size += len(chunk)

    if file_size == 0:
        os.remove(tmp_path)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty",
        )

    # Upload to R2
    r2_key = f"{user_id}/{filename}"
    upload_audio(tmp_path, r2_key)

    # Clean up temp file
    os.remove(tmp_path)

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