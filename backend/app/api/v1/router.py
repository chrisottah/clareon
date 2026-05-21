from fastapi import APIRouter
from app.api.v1.endpoints import health, auth, meetings, transcripts, intelligence

api_router = APIRouter()

api_router.include_router(health.router, prefix="", tags=["System"])
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(meetings.router, prefix="/meetings", tags=["Meetings"])
api_router.include_router(transcripts.router, prefix="/transcripts", tags=["Transcripts"])
api_router.include_router(intelligence.router, prefix="/intelligence", tags=["Intelligence"])