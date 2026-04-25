import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.config import settings
from app.core.schemas.rebalance import RebalanceApplyRequest, RebalanceRequest, RebalanceResponse
from app.core.services.rebalance_service import RebalanceService, RebalanceValidationError
from app.infrastructure.database.base import get_db
from app.infrastructure.database.models import User
from app.infrastructure.database.repositories import EventRepository
from app.infrastructure.external.openai_client import get_llm_client
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/events/rebalance", tags=["Rebalance"])


@router.post("", response_model=RebalanceResponse)
@limiter.limit("10/minute")
async def propose_rebalance(
    request: Request,
    body: RebalanceRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Dry-run: ask LLM to suggest an optimized schedule for selected days.
    Nothing is saved. Use /rebalance/apply to commit changes.
    """
    event_repo = EventRepository(db)
    rebalance_model = settings.LLM_REBALANCE_MODEL or settings.LLM_MODEL
    service = RebalanceService(get_llm_client(), model=rebalance_model)
    try:
        result = await service.propose(current_user.id, body, event_repo)
    except RebalanceValidationError as exc:
        logger.warning("rebalance_propose_failed user_id=%s error=%s", current_user.id, exc)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"LLM returned an invalid schedule after retries: {exc}",
        )
    logger.info(
        "rebalance_proposed user_id=%s days=%s changed=%d",
        current_user.id,
        [str(d.date) for d in body.days],
        result.changed_count,
    )
    return result


@router.post("/apply", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
async def apply_rebalance(
    request: Request,
    body: RebalanceApplyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Apply a subset of rebalance suggestions returned by the dry-run endpoint.
    """
    event_repo = EventRepository(db)
    service = RebalanceService(get_llm_client())
    try:
        await service.apply(current_user.id, body, event_repo)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )
    logger.info(
        "rebalance_applied user_id=%s events_count=%d",
        current_user.id,
        len(body.events),
    )
