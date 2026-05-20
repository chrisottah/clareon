from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.session import engine, Base
from app.models import user, meeting  # noqa: F401 — ensures models are registered


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown logic."""
    # Create tables on startup (Alembic handles this in production)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Cleanup on shutdown
    await engine.dispose()


app = FastAPI(
    title="Clareon API",
    description="AI-powered meeting intelligence backend",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS — allow Flutter app (dev + prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API routes
app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["Root"])
async def root():
    return {
        "app": "Clareon",
        "version": "0.1.0",
        "environment": settings.APP_ENV,
        "docs": "/docs",
    }
