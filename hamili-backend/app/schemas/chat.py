from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ChatMessageCreate(BaseModel):
    content: str


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    role: str
    content: str
    created_at: datetime


class ChatReply(BaseModel):
    reply: str
    # False when the AI backend was unavailable (quota exhausted) and `reply`
    # is the fallback message — lets the app show Hami "sleeping".
    available: bool = True
