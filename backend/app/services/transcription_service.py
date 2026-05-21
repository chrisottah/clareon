import os
import logging
from dataclasses import dataclass

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

    import whisperx

    model_size = os.getenv("WHISPER_MODEL", "base")
    device = os.getenv("WHISPER_DEVICE", "cpu")
    compute_type = "int8"

    logger.info(f"Loading WhisperX model: {model_size} on {device}")
    model = whisperx.load_model(model_size, device, compute_type=compute_type)

    logger.info(f"Transcribing: {audio_path}")
    result = model.transcribe(audio_path, batch_size=8)

    raw_segments = result.get("segments", [])
    logger.info(f"Raw segments: {len(raw_segments)}")

    output: list[TranscriptSegment] = []
    segment_index = 0
    consecutive_fillers = 0
    filler_start = None
    filler_end = None

    for seg in raw_segments:
        text = seg["text"].strip()
        if not text:
            continue

        confidence = float(seg.get("avg_logprob", -0.5))
        confidence = max(0.0, min(1.0, confidence + 1.0))

        if _is_filler(text):
            consecutive_fillers += 1
            if filler_start is None:
                filler_start = seg["start"]
            filler_end = seg["end"]

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
                start_time=seg["start"],
                end_time=seg["end"],
                text=text,
                speaker=None,
                confidence=confidence,
                segment_index=segment_index,
            ))
            segment_index += 1

    logger.info(f"Transcription complete: {len(output)} segments")
    return output