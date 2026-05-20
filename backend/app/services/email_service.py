import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings

logger = logging.getLogger(__name__)


def _send_email(to_email: str, subject: str, html_body: str) -> None:
    """Send an email via SMTP. Logs errors instead of crashing."""
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{settings.EMAILS_FROM_NAME} <{settings.EMAILS_FROM_EMAIL}>"
        msg["To"] = to_email
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.EMAILS_FROM_EMAIL, to_email, msg.as_string())

        logger.info(f"Email sent to {to_email}: {subject}")
    except Exception as e:
        # Don't crash the request if email fails — log it
        logger.error(f"Failed to send email to {to_email}: {e}")


def send_verification_email(to_email: str, full_name: str, token: str) -> None:
    subject = "Verify your Clareon account"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2563EB;">Welcome to Clareon, {full_name}!</h2>
        <p>Please verify your email address to get started.</p>
        <p style="margin: 32px 0;">
            <a href="#" style="background:#2563EB;color:white;padding:12px 24px;
               border-radius:8px;text-decoration:none;font-weight:600;">
                Verification Token: {token}
            </a>
        </p>
        <p style="color:#666;font-size:14px;">
            Enter this token in the app to verify your account.<br>
            This token expires in 24 hours.
        </p>
    </div>
    """
    _send_email(to_email, subject, html)


def send_password_reset_email(to_email: str, full_name: str, token: str) -> None:
    subject = "Reset your Clareon password"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2563EB;">Password Reset</h2>
        <p>Hi {full_name}, here is your password reset token:</p>
        <p style="font-size: 28px; font-weight: bold; letter-spacing: 4px;
                  color: #2563EB; margin: 32px 0;">{token}</p>
        <p style="color:#666;font-size:14px;">
            Enter this token in the app to reset your password.<br>
            This token expires in 1 hour.
        </p>
        <p style="color:#666;font-size:14px;">
            If you didn't request this, ignore this email.
        </p>
    </div>
    """
    _send_email(to_email, subject, html)
