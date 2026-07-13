from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.core.rate_limit import AI_LIMIT, limiter
from app.db.session import get_db
from app.models.ai import AIChatMessage
from app.models.user import User
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ChatReply
from app.services.agent_service import AgentService
from app.services.ai.base_provider import AIProviderUnavailable

# Shown when Gemini's quota is exhausted — "tomorrow" because the free-tier
# quota resets daily.
_SERVERS_DOWN_REPLY = "Hami's servers are down right now, try again tomorrow. 💤"

router = APIRouter(prefix="/chat", tags=["chat"])


@router.get("/history", response_model=list[ChatMessageOut])
def get_history(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return (
        db.query(AIChatMessage)
        .filter(AIChatMessage.user_id == current_user.id)
        .order_by(AIChatMessage.created_at.asc())
        .all()
    )


@router.post("/message", response_model=ChatReply)
@limiter.limit(AI_LIMIT)
def send_message(
    request: Request,
    payload: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Persist the user's message first
    user_message = AIChatMessage(user_id=current_user.id, role="user", content=payload.content)
    db.add(user_message)
    db.commit()

    # Build history for context, then ask Hami
    history = (
        db.query(AIChatMessage)
        .filter(AIChatMessage.user_id == current_user.id)
        .order_by(AIChatMessage.created_at.asc())
        .all()
    )
    message_history = [{"role": m.role, "content": m.content} for m in history]

    try:
        # The agent may answer normally OR perform an action (add a goal,
        # change the profile, etc.) and tell us which app areas changed.
        result = AgentService(db).respond(current_user, message_history)
    except AIProviderUnavailable:
        # Quota exhausted — surface a friendly message and don't persist it as
        # real chat history (the user's question stays; Hami just couldn't answer).
        return ChatReply(reply=_SERVERS_DOWN_REPLY, available=False)

    reply_text = result["reply"]
    assistant_message = AIChatMessage(user_id=current_user.id, role="assistant", content=reply_text)
    db.add(assistant_message)
    db.commit()

    return ChatReply(reply=reply_text, changed=result.get("changed", []), effect=result.get("effect"))
