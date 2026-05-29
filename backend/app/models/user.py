import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # KingsChat OAuth
    kingschat_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    kingschat_access_token: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    kingschat_refresh_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    # Email verification — 6-digit OTP
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_otp: Mapped[str | None] = mapped_column(String(6), nullable=True)
    verification_otp_expires: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Password reset — 6-digit OTP
    reset_otp: Mapped[str | None] = mapped_column(String(6), nullable=True)
    reset_otp_expires: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self):
        return f"<User {self.email or self.kingschat_id}>"