import json
import logging
import concurrent.futures
from groq import Groq
from app.core.config import settings

logger = logging.getLogger(__name__)


def _build_transcript_text(segments) -> str:
    lines = []
    current_speaker = None
    for seg in segments:
        speaker = seg.speaker or "Speaker"
        if speaker != current_speaker:
            lines.append(f"\n{speaker}:")
            current_speaker = speaker
        lines.append(f"  {seg.text}")
    return "\n".join(lines)


def _call_groq(prompt: str, max_tokens: int = 1024) -> str:
    client = Groq(api_key=settings.GROQ_API_KEY)
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens,
        temperature=0.3,
    )
    return response.choices[0].message.content.strip()


def generate_summary(transcript_text: str) -> str:
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
    return _call_groq(prompt, max_tokens=1024)


def generate_action_points(transcript_text: str) -> list[str]:
    prompt = f"""You are an expert at extracting action items from meetings.

From the transcript below, extract all action points, tasks, and next steps.
Return ONLY a JSON array of strings. Each string is one action point.
Be specific about who should do what when possible.
If no action points exist, return an empty array.

Example format: ["John to send the report by Friday", "Team to review the proposal"]

TRANSCRIPT:
{transcript_text}

ACTION POINTS (JSON array only, no other text):"""

    raw = _call_groq(prompt, max_tokens=512)
    try:
        raw = raw.strip()
        if not raw.startswith("["):
            start = raw.find("[")
            if start == -1:
                return []
            raw = raw[start:]
        if not raw.endswith("]"):
            end = raw.rfind("]")
            if end == -1:
                return []
            raw = raw[:end + 1]
        return json.loads(raw)
    except Exception:
        lines = [l.strip("•-– ").strip() for l in raw.split("\n") if l.strip()]
        return [l for l in lines if len(l) > 10]


def generate_key_insights(transcript_text: str) -> list[str]:
    prompt = f"""You are an expert meeting analyst.

From the transcript below, extract 3-6 key insights or important discussion points.
Return ONLY a JSON array of strings. Each string is one insight.
Focus on: important decisions, notable disagreements, significant ideas, critical information.

Example format: ["The team agreed to delay the launch by 2 weeks", "Budget concerns were raised"]

TRANSCRIPT:
{transcript_text}

KEY INSIGHTS (JSON array only, no other text):"""

    raw = _call_groq(prompt, max_tokens=512)
    try:
        raw = raw.strip()
        if not raw.startswith("["):
            start = raw.find("[")
            if start == -1:
                return []
            raw = raw[start:]
        if not raw.endswith("]"):
            end = raw.rfind("]")
            if end == -1:
                return []
            raw = raw[:end + 1]
        return json.loads(raw)
    except Exception:
        lines = [l.strip("•-– ").strip() for l in raw.split("\n") if l.strip()]
        return [l for l in lines if len(l) > 10]


def generate_meeting_intelligence(segments) -> dict:
    if not segments:
        return {
            "summary": "No transcript available.",
            "action_points": [],
            "key_insights": [],
        }

    transcript_text = _build_transcript_text(segments)
    logger.info("Generating intelligence in parallel via Groq...")

    # Run all three in parallel — cuts total time by ~3x
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        future_summary = executor.submit(generate_summary, transcript_text)
        future_actions = executor.submit(generate_action_points, transcript_text)
        future_insights = executor.submit(generate_key_insights, transcript_text)

        summary = future_summary.result()
        action_points = future_actions.result()
        key_insights = future_insights.result()

    logger.info("Intelligence generation complete")
    return {
        "summary": summary,
        "action_points": action_points,
        "key_insights": key_insights,
    }