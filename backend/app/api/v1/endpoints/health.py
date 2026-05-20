from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from redis.asyncio import Redis

from app.db.session import get_db
from app.core.config import settings

router = APIRouter()


async def get_redis() -> Redis:
    client = Redis.from_url(settings.REDIS_URL, decode_responses=True)
    try:
        yield client
    finally:
        await client.aclose()


@router.get("/health", tags=["System"])
async def health_check(
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """
    System health check.
    Returns status of the API, database, and Redis.
    """
    health = {
        "status": "ok",
        "api": "ok",
        "database": "unknown",
        "redis": "unknown",
    }

    # Check database
    try:
        await db.execute(text("SELECT 1"))
        health["database"] = "ok"
    except Exception as e:
        health["database"] = f"error: {str(e)}"
        health["status"] = "degraded"

    # Check Redis
    try:
        await redis.ping()
        health["redis"] = "ok"
    except Exception as e:
        health["redis"] = f"error: {str(e)}"
        health["status"] = "degraded"

    return health
