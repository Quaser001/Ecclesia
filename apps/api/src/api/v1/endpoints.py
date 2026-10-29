"""API v1 router — aggregates all endpoint routers."""

from fastapi import APIRouter

from src.api.v1.auth import router as auth_router
from src.api.v1.consent import router as consent_router
from src.api.v1.insights import router as insights_router
from src.api.v1.prescriptions import router as prescriptions_router
from src.api.v1.profiles import router as profiles_router
from src.api.v1.scans import router as scans_router

router = APIRouter()

# Health check
@router.get("/health", status_code=200, tags=["health"])
async def health_check():
    """Verify the API is online."""
    return {"status": "ok", "service": "CalFit API"}


# Feature routers
router.include_router(auth_router)
router.include_router(consent_router)
router.include_router(profiles_router)
router.include_router(prescriptions_router)
router.include_router(scans_router)
router.include_router(insights_router)
