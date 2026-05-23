from fastapi import APIRouter, Depends, status, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.schemas.auth import (
    SignupRequest, LoginRequest, TokenResponse, RefreshRequest,
    ForgotPasswordRequest, ResetPasswordRequest, VerifyOTPRequest,
    KingsChatAuthRequest, UserResponse, MessageResponse,
)
from app.services import auth_service
from app.models.user import User

router = APIRouter()


@router.post("/signup", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def signup(data: SignupRequest, db: AsyncSession = Depends(get_db)):
    """Create a new account. Sends verification OTP via email."""
    await auth_service.signup(db, data)
    return {"message": "Account created. Please check your email for your 6-digit verification code."}


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login with email and password. Returns JWT tokens."""
    return await auth_service.login(db, data)


@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(data: VerifyOTPRequest, db: AsyncSession = Depends(get_db)):
    """Verify email address using 6-digit OTP from email."""
    await auth_service.verify_email_otp(db, data.email, data.otp)
    return {"message": "Email verified successfully. You can now log in."}


@router.post("/resend-otp", response_model=MessageResponse)
async def resend_otp(data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Resend verification OTP to email."""
    await auth_service.resend_verification_otp(db, data.email)
    return {"message": "If your email is registered and unverified, a new code has been sent."}


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Send password reset OTP via email."""
    await auth_service.forgot_password(db, data.email)
    return {"message": "If an account exists with this email, a reset code has been sent."}


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(data: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Reset password using OTP from email."""
    await auth_service.reset_password(db, data.email, data.otp, data.new_password)
    return {"message": "Password reset successfully. You can now log in."}


@router.post("/kingschat", response_model=TokenResponse)
async def kingschat_login(data: KingsChatAuthRequest, db: AsyncSession = Depends(get_db)):
    """Login via KingsChat OAuth. Creates account if first time."""
    return await auth_service.kingschat_auth(db, data)


@router.api_route("/kingschat/callback", methods=["GET", "POST"], response_class=HTMLResponse)
async def kingschat_callback(request: Request):
    """KingsChat redirects here after login. Extracts tokens from GET or POST, then redirects to app custom scheme."""
    access_token = None
    refresh_token = None

    # Try GET query params
    access_token = request.query_params.get("accessToken") or request.query_params.get("access_token")
    refresh_token = request.query_params.get("refreshToken") or request.query_params.get("refresh_token")

    # Try POST form data
    if not access_token:
        try:
            form = await request.form()
            access_token = form.get("accessToken") or form.get("access_token")
            refresh_token = form.get("refreshToken") or form.get("refresh_token")
        except Exception:
            pass

    if not access_token:
        return HTMLResponse(content="<h1>Login failed: no token received</h1>", status_code=400)

    refresh_param = f"&refreshToken={refresh_token}" if refresh_token else ""
    redirect_url = f"clareon://callback?accessToken={access_token}{refresh_param}"

    return HTMLResponse(f"""
    <!DOCTYPE html>
    <html>
    <head><title>Login Complete</title></head>
    <body style="background:#0B0F19;color:white;font-family:sans-serif;text-align:center;padding-top:40vh;">
        <h2 style="color:#2563EB;">Login Successful</h2>
        <p>Redirecting back to Clareon...</p>
        <script>
            window.location.href = "{redirect_url}";
        </script>
    </body>
    </html>
    """)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Get new access token using refresh token."""
    return await auth_service.refresh_tokens(db, data.refresh_token)


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current logged-in user profile."""
    return current_user