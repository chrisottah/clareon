import os
import logging
from dataclasses import dataclass
from groq import Groq
from app.core.config import settings

logger = logging.getLogger(__name__)

FILLER_WORDS = {
    "yeah", "yep", "mhmm", "uh", "um", "okay", "ok",
    "right", "sure", "alright", "mmm", "hmm",
}
FILLER_COLLAPSE_THRESHOLD = 2


@dataclass
class TranscriptSegment:
    start_time: float
    end_time: float
    text: str
    speaker: str | None
    confidence: float
    segment_index: int


def _is_filler(text: str) -> bool:
    words = text.lower().strip().split()
    return len(words) <= 2 and all(w in FILLER_WORDS for w in words)


def transcribe_audio(audio_path: str) -> list[TranscriptSegment]:
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    if not settings.GROQ_API_KEY:
        raise ValueError("GROQ_API_KEY not set in environment")

    client = Groq(api_key=settings.GROQ_API_KEY)

    logger.info(f"Transcribing via Groq: {audio_path}")

    with open(audio_path, "rb") as audio_file:
        response = client.audio.transcriptions.create(
            file=(os.path.basename(audio_path), audio_file),
            model="whisper-large-v3",
            response_format="verbose_json",
            timestamp_granularities=["segment"],
        )

    # Groq returns segments as dicts
    raw_segments = response.segments or []
    logger.info(f"Groq returned {len(raw_segments)} segments")

    output: list[TranscriptSegment] = []
    segment_index = 0
    consecutive_fillers = 0
    filler_start = None
    filler_end = None

    for seg in raw_segments:
        # Handle both dict and object responses
        if isinstance(seg, dict):
            text = seg.get("text", "").strip()
            start = float(seg.get("start", 0))
            end = float(seg.get("end", 0))
            confidence = float(seg.get("avg_logprob", -0.5))
        else:
            text = seg.text.strip()
            start = float(seg.start)
            end = float(seg.end)
            confidence = float(getattr(seg, "avg_logprob", -0.5))

        if not text:
            continue

        confidence = max(0.0, min(1.0, confidence + 1.0))

        if _is_filler(text):
            consecutive_fillers += 1
            if filler_start is None:
                filler_start = start
            filler_end = end

            if consecutive_fillers >= FILLER_COLLAPSE_THRESHOLD:
                output.append(TranscriptSegment(
                    start_time=filler_start,
                    end_time=filler_end,
                    text="(audience agrees)",
                    speaker=None,
                    confidence=1.0,
                    segment_index=segment_index,
                ))
                segment_index += 1
                consecutive_fillers = 0
                filler_start = None
                filler_end = None
        else:
            consecutive_fillers = 0
            filler_start = None
            filler_end = None

            output.append(TranscriptSegment(
                start_time=start,
                end_time=end,
                text=text,
                speaker=None,
                confidence=confidence,
                segment_index=segment_index,
            ))
            segment_index += 1

    logger.info(f"Transcription complete: {len(output)} segments")
    return output