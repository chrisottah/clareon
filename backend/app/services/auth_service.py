import random
from datetime import datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
import httpx

from app.models.user import User
from app.schemas.auth import (
    SignupRequest, LoginRequest, TokenResponse,
    KingsChatAuthRequest,
)
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.services.email_service import send_verification_otp, send_password_reset_otp

_ph = PasswordHasher()
KINGSCHAT_PROFILE_URL = "https://connect.kingsch.at/api/profile"


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return _ph.verify(hashed, plain)
    except VerifyMismatchError:
        return False


def _generate_otp() -> str:
    return str(random.randint(100000, 999999))


def _otp_expiry() -> datetime:
    return datetime.now(timezone.utc) + timedelta(minutes=10)


async def signup(db: AsyncSession, data: SignupRequest) -> User:
    result = await db.execute(select(User).where(User.email == data.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    otp = _generate_otp()
    user = User(
        email=data.email,
        full_name=data.full_name,
        hashed_password=hash_password(data.password),
        verification_otp=otp,
        verification_otp_expires=_otp_expiry(),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    send_verification_otp(user.email, user.full_name, otp)
    return user


async def login(db: AsyncSession, data: LoginRequest) -> TokenResponse:
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not verify_password(data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been deactivated",
        )

    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please verify your email before logging in",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


async def verify_email_otp(db: AsyncSession, email: str, otp: str) -> User:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=400, detail="User not found")

    if user.is_verified:
        return user

    if not user.verification_otp or user.verification_otp != otp:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    if user.verification_otp_expires < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=400,
            detail="Verification code has expired. Please request a new one.",
        )

    user.is_verified = True
    user.verification_otp = None
    user.verification_otp_expires = None
    await db.commit()
    await db.refresh(user)
    return user


async def resend_verification_otp(db: AsyncSession, email: str) -> None:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user or user.is_verified:
        return

    otp = _generate_otp()
    user.verification_otp = otp
    user.verification_otp_expires = _otp_expiry()
    await db.commit()

    send_verification_otp(user.email, user.full_name, otp)


async def forgot_password(db: AsyncSession, email: str) -> None:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        return

    otp = _generate_otp()
    user.reset_otp = otp
    user.reset_otp_expires = _otp_expiry()
    await db.commit()

    send_password_reset_otp(user.email, user.full_name, otp)


async def reset_password(db: AsyncSession, email: str, otp: str, new_password: str) -> None:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user or not user.reset_otp or user.reset_otp != otp:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    if user.reset_otp_expires < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Reset code has expired")

    user.hashed_password = hash_password(new_password)
    user.reset_otp = None
    user.reset_otp_expires = None
    await db.commit()


async def kingschat_auth(db: AsyncSession, data: KingsChatAuthRequest) -> TokenResponse:
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                KINGSCHAT_PROFILE_URL,
                headers={"Authorization": f"Bearer {data.access_token}"},
            )
            response.raise_for_status()
            profile_data = response.json()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Failed to verify KingsChat token: {e}",
        )

    try:
        profile = profile_data["profile"]["user"]
        kingschat_id = profile["user_id"]
        full_name = profile.get("name") or profile.get("username") or "KingsChat User"
        avatar_url = profile.get("avatar_url")
    except (KeyError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid profile response from KingsChat",
        )

    result = await db.execute(
        select(User).where(User.kingschat_id == kingschat_id)
    )
    user = result.scalar_one_or_none()

    if user:
        user.kingschat_access_token = data.access_token
        user.kingschat_refresh_token = data.refresh_token
        user.avatar_url = avatar_url
        await db.commit()
        await db.refresh(user)
    else:
        user = User(
            kingschat_id=kingschat_id,
            full_name=full_name,
            avatar_url=avatar_url,
            kingschat_access_token=data.access_token,
            kingschat_refresh_token=data.refresh_token,
            is_verified=True,
            is_active=True,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


async def refresh_tokens(db: AsyncSession, refresh_token: str) -> TokenResponse:
    from jose import JWTError
    try:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise ValueError()
        user_id = payload.get("sub")
    except (JWTError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )