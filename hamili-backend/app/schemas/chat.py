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
    # is the fallback message.
    available: bool = True
    # App areas the reply changed (e.g. ["goals"], ["profile"]) so the client
    # can refresh those tabs. Empty for ordinary answers.
    changed: list[str] = []
