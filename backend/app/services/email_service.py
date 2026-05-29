import logging
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


def _send_email(to_email: str, subject: str, html_body: str) -> None:
    """Send email via Brevo HTTP API (works on Railway)."""
    try:
        response = httpx.post(
            "https://api.brevo.com/v3/smtp/email",
            headers={
                "api-key": settings.BREVO_API_KEY,
                "Content-Type": "application/json",
            },
            json={
                "sender": {
                    "name": settings.EMAILS_FROM_NAME,
                    "email": settings.EMAILS_FROM_EMAIL,
                },
                "to": [{"email": to_email}],
                "subject": subject,
                "htmlContent": html_body,
            },
            timeout=10,
        )
        response.raise_for_status()
        logger.info(f"Email sent to {to_email}: {subject}")
    except Exception as e:
        logger.error(f"Failed to send email to {to_email}: {e}")


def send_verification_otp(to_email: str, full_name: str, otp: str) -> None:
    subject = "Your Clareon verification code"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2563EB;">Welcome to Clareon, {full_name}!</h2>
        <p>Your email verification code is:</p>
        <div style="text-align: center; margin: 32px 0;">
            <span style="font-size: 48px; font-weight: bold; letter-spacing: 12px;
                         color: #2563EB; font-family: monospace;">{otp}</span>
        </div>
        <p style="color:#666; font-size:14px;">
            This code expires in <strong>10 minutes</strong>.<br>
            If you didn't create a Clareon account, ignore this email.
        </p>
    </div>
    """
    _send_email(to_email, subject, html)


def send_password_reset_otp(to_email: str, full_name: str, otp: str) -> None:
    subject = "Your Clareon password reset code"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2563EB;">Password Reset</h2>
        <p>Hi {full_name}, your password reset code is:</p>
        <div style="text-align: center; margin: 32px 0;">
            <span style="font-size: 48px; font-weight: bold; letter-spacing: 12px;
                         color: #2563EB; font-family: monospace;">{otp}</span>
        </div>
        <p style="color:#666; font-size:14px;">
            This code expires in <strong>10 minutes</strong>.<br>
            If you didn't request this, ignore this email.
        </p>
    </div>
    """
    _send_email(to_email, subject, html)