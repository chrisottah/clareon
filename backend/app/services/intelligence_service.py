import json
import logging
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


def _build_transcript_text(segments) -> str:
    """Convert segments into readable transcript for the AI prompt."""
    lines = []
    current_speaker = None
    for seg in segments:
        speaker = seg.speaker or "Speaker"
        if speaker != current_speaker:
            lines.append(f"\n{speaker}:")
            current_speaker = speaker
        lines.append(f"  {seg.text}")
    return "\n".join(lines)


def _call_ollama(prompt: str) -> str:
    """Call local Ollama API synchronously."""
    try:
        with httpx.Client(timeout=120.0) as client:
            response = client.post(
                f"{settings.OLLAMA_URL}/api/generate",
                json={
                    "model": settings.OLLAMA_MODEL,
                    "prompt": prompt,
                    "stream": False,
                },
            )
            response.raise_for_status()
            return response.json()["response"].strip()
    except Exception as e:
        logger.error(f"Ollama call failed: {e}")
        raise


def generate_summary(transcript_text: str) -> str:
    """Generate intelligent meeting minutes."""
    prompt = f"""You are an expert meeting analyst. Based on the transcript below, write clear and concise meeting minutes.

Include:
- Main topics discussed
- Key decisions made
- Important points raised
- Overall outcome of the meeting

Be professional, structured, and concise. Write in paragraph form.

TRANSCRIPT:
{transcript_text}

MEETING MINUTES:"""

    return _call_ollama(prompt)


def generate_action_points(transcript_text: str) -> list[str]:
    """Extract action items and tasks from the meeting."""
    prompt = f"""You are an expert at extracting action items from meetings.

From the transcript below, extract all action points, tasks, and next steps.
Return ONLY a JSON array of strings. Each string is one action point.
Be specific about who should do what when possible.
If no action points exist, return an empty array.

Example format: ["John to send the report by Friday", "Team to review the proposal", "Schedule follow-up meeting next week"]

TRANSCRIPT:
{transcript_text}

ACTION POINTS (JSON array only, no other text):"""

    raw = _call_ollama(prompt)
    try:
        # Clean up common JSON issues
        raw = raw.strip()
        if not raw.startswith("["):
            raw = raw[raw.find("["):]
        if not raw.endswith("]"):
            raw = raw[:raw.rfind("]") + 1]
        return json.loads(raw)
    except Exception:
        logger.warning("Could not parse action points JSON, extracting manually")
        # Fallback: split by newlines and clean up
        lines = [l.strip("•-– ").strip() for l in raw.split("\n") if l.strip()]
        return [l for l in lines if len(l) > 10]


def generate_key_insights(transcript_text: str) -> list[str]:
    """Extract key discussion points and insights."""
    prompt = f"""You are an expert meeting analyst.

From the transcript below, extract 3-6 key insights or important discussion points.
Return ONLY a JSON array of strings. Each string is one insight.
Focus on: important decisions, notable disagreements, significant ideas, and critical information shared.

Example format: ["The team agreed to delay the launch by 2 weeks", "Budget concerns were raised regarding the marketing plan"]

TRANSCRIPT:
{transcript_text}

KEY INSIGHTS (JSON array only, no other text):"""

    raw = _call_ollama(prompt)
    try:
        raw = raw.strip()
        if not raw.startswith("["):
            raw = raw[raw.find("["):]
        if not raw.endswith("]"):
            raw = raw[:raw.rfind("]") + 1]
        return json.loads(raw)
    except Exception:
        logger.warning("Could not parse insights JSON, extracting manually")
        lines = [l.strip("•-– ").strip() for l in raw.split("\n") if l.strip()]
        return [l for l in lines if len(l) > 10]


def generate_meeting_intelligence(segments) -> dict:
    """
    Run all AI analysis on transcript segments.
    Returns dict with summary, action_points, key_insights.
    """
    if not segments:
        return {
            "summary": "No transcript available.",
            "action_points": [],
            "key_insights": [],
        }

    transcript_text = _build_transcript_text(segments)

    logger.info("Generating meeting summary...")
    summary = generate_summary(transcript_text)

    logger.info("Extracting action points...")
    action_points = generate_action_points(transcript_text)

    logger.info("Extracting key insights...")
    key_insights = generate_key_insights(transcript_text)

    return {
        "summary": summary,
        "action_points": action_points,
        "key_insights": key_insights,
    }