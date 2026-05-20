from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.schemas.auth import (
    SignupRequest, LoginRequest, TokenResponse, RefreshRequest,
    ForgotPasswordRequest, ResetPasswordRequest, VerifyEmailRequest,
    UserResponse, MessageResponse,
)
from app.services import auth_service
from app.models.user import User

router = APIRouter()


@router.post("/signup", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def signup(data: SignupRequest, db: AsyncSession = Depends(get_db)):
    """Create a new account. Sends verification email."""
    await auth_service.signup(db, data)
    return {"message": "Account created. Please check your email to verify your account."}


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login with email and password. Returns JWT tokens."""
    return await auth_service.login(db, data)


@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(data: VerifyEmailRequest, db: AsyncSession = Depends(get_db)):
    """Verify email address using token from email."""
    await auth_service.verify_email(db, data.token)
    return {"message": "Email verified successfully. You can now log in."}


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Send password reset email."""
    await auth_service.forgot_password(db, data.email)
    return {"message": "If an account exists with this email, a reset link has been sent."}


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(data: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Reset password using token from email."""
    await auth_service.reset_password(db, data.token, data.new_password)
    return {"message": "Password reset successfully. You can now log in."}


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Get new access token using refresh token."""
    return await auth_service.refresh_tokens(db, data.refresh_token)


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current logged-in user profile."""
    return current_user
