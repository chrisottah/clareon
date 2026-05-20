from fastapi import APIRouter
from app.api.v1.endpoints import health, auth, meetings

api_router = APIRouter()

api_router.include_router(health.router, prefix="", tags=["System"])
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(meetings.router, prefix="/meetings", tags=["Meetings"])
