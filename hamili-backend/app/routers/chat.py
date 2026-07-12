from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.ai import AIChatMessage
from app.models.user import User
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ChatReply
from app.services.insight_service import InsightService

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
def send_message(
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

    reply_text = InsightService(db).chat(current_user, message_history)

    assistant_message = AIChatMessage(user_id=current_user.id, role="assistant", content=reply_text)
    db.add(assistant_message)
    db.commit()

    return ChatReply(reply=reply_text)
