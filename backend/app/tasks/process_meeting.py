import os
import json
import logging
from sqlalchemy import create_engine, update
from sqlalchemy.orm import sessionmaker, Session
from app.core.celery_app import celery_app
from app.core.config import settings
from app.models.meeting import Meeting, MeetingStatus
from app.models.transcript import TranscriptSegment
from app.models.meeting_intelligence import MeetingIntelligence

logger = logging.getLogger(__name__)

# Synchronous engine – safe for Celery tasks
sync_engine = create_engine(
    settings.DATABASE_URL.replace("+asyncpg", "+psycopg2"),
    echo=False,
)
SyncSession = sessionmaker(sync_engine)


def _set_status_sync(meeting_id: str, status: MeetingStatus):
    with SyncSession() as session:
        session.execute(
            update(Meeting)
            .where(Meeting.id == meeting_id)
            .values(status=status)
        )
        session.commit()


def _get_meeting_sync(meeting_id: str):
    with SyncSession() as session:
        return session.query(Meeting).filter(Meeting.id == meeting_id).one_or_none()


def _save_segments_sync(meeting_id: str, segments):
    with SyncSession() as session:
        for seg in segments:
            db_seg = TranscriptSegment(
                meeting_id=meeting_id,
                start_time=seg.start_time,
                end_time=seg.end_time,
                text=seg.text,
                speaker=seg.speaker,
                confidence=seg.confidence,
                segment_index=seg.segment_index,
            )
            session.add(db_seg)
        session.commit()


def _save_intelligence_sync(meeting_id: str, intel: dict):
    with SyncSession() as session:
        obj = MeetingIntelligence(
            meeting_id=meeting_id,
            summary=intel["summary"],
            action_points=json.dumps(intel["action_points"]),
            key_insights=json.dumps(intel["key_insights"]),
        )
        session.add(obj)
        session.commit()


def _get_segments_sync(meeting_id: str):
    with SyncSession() as session:
        return (
            session.query(TranscriptSegment)
            .filter(TranscriptSegment.meeting_id == meeting_id)
            .order_by(TranscriptSegment.segment_index)
            .all()
        )


@celery_app.task(bind=True, max_retries=3)
def process_meeting_task(self, meeting_id: str):
    try:
        logger.info(f"Processing meeting: {meeting_id}")
        _set_status_sync(meeting_id, MeetingStatus.processing)

        meeting = _get_meeting_sync(meeting_id)
        if not meeting:
            raise ValueError(f"Meeting {meeting_id} not found")

        # Download audio from R2 to temp location
        from app.services.storage_service import download_audio, delete_audio
        r2_key = f"{meeting.user_id}/{meeting.audio_filename}"
        tmp_path = f"/tmp/{meeting.audio_filename}"
        download_audio(r2_key, tmp_path)

        try:
            # Step 1 — Transcribe
            from app.services.transcription_service import transcribe_audio
            logger.info("Step 1: Transcribing audio...")
            segments = transcribe_audio(tmp_path)

            # Step 2 — Diarize
            from app.services.diarization_service import diarize_audio, assign_speakers
            logger.info("Step 2: Running speaker diarization...")
            speaker_segments = diarize_audio(tmp_path)
            segments = assign_speakers(segments, speaker_segments)

            # Step 3 — Save transcript
            logger.info("Step 3: Saving transcript...")
            _save_segments_sync(meeting_id, segments)

            # Step 4 — Generate AI intelligence
            from app.services.intelligence_service import generate_meeting_intelligence
            logger.info("Step 4: Generating AI intelligence...")
            saved_segments = _get_segments_sync(meeting_id)
            intel = generate_meeting_intelligence(saved_segments)
            _save_intelligence_sync(meeting_id, intel)

            _set_status_sync(meeting_id, MeetingStatus.completed)
            logger.info(f"Meeting {meeting_id} fully processed")

        finally:
            # Always clean up temp file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
            # Delete from R2 after processing
            delete_audio(r2_key)

        return {"status": "completed", "meeting_id": meeting_id}

    except Exception as e:
        logger.error(f"Processing failed for {meeting_id}: {e}")
        _set_status_sync(meeting_id, MeetingStatus.failed)
        raise self.retry(exc=e, countdown=60)