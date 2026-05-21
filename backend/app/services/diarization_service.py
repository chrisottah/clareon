import os
import logging
from dataclasses import dataclass
from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class SpeakerSegment:
    start_time: float
    end_time: float
    speaker: str  # e.g. "Speaker 1"


def diarize_audio(audio_path: str) -> list[SpeakerSegment]:
    """
    Run speaker diarization on audio file.
    Returns time segments labeled by speaker.
    Requires HUGGINGFACE_TOKEN in environment.
    """
    if not settings.HUGGINGFACE_TOKEN:
        logger.warning("No HuggingFace token — skipping diarization")
        return []

    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    try:
        from pyannote.audio import Pipeline
        import torch

        logger.info("Loading diarization pipeline...")
        pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=settings.HUGGINGFACE_TOKEN,
        )

        # Use GPU if available
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        pipeline = pipeline.to(device)
        logger.info(f"Diarization running on: {device}")

        logger.info(f"Diarizing: {audio_path}")
        diarization = pipeline(audio_path)

        results: list[SpeakerSegment] = []
        # Normalize speaker labels to friendly names
        speaker_map: dict[str, str] = {}
        counter = 1

        for turn, _, speaker in diarization.itertracks(yield_label=True):
            if speaker not in speaker_map:
                speaker_map[speaker] = f"Speaker {counter}"
                counter += 1
            results.append(SpeakerSegment(
                start_time=round(turn.start, 2),
                end_time=round(turn.end, 2),
                speaker=speaker_map[speaker],
            ))

        logger.info(f"Diarization complete: {len(speaker_map)} speakers found")
        return results

    except Exception as e:
        logger.error(f"Diarization failed: {e}")
        # Non-fatal — return empty so transcription still works
        return []


def assign_speakers(
    transcript_segments: list,
    speaker_segments: list[SpeakerSegment],
) -> list:
    """
    Match each transcript segment to the speaker talking at that time.
    Uses midpoint of transcript segment to find best speaker match.
    """
    if not speaker_segments:
        return transcript_segments

    for seg in transcript_segments:
        midpoint = (seg.start_time + seg.end_time) / 2

        # Find speaker segment with most overlap at midpoint
        best_speaker = None
        for sp in speaker_segments:
            if sp.start_time <= midpoint <= sp.end_time:
                best_speaker = sp.speaker
                break

        # Fallback: find nearest speaker segment
        if best_speaker is None and speaker_segments:
            nearest = min(
                speaker_segments,
                key=lambda s: abs(((s.start_time + s.end_time) / 2) - midpoint),
            )
            best_speaker = nearest.speaker

        seg.speaker = best_speaker

    return transcript_segments