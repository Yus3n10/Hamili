from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ChatMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=2000)


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    role: str
    content: str
    created_at: datetime


class ChatReply(BaseModel):
    reply: str
    available: bool = True
    changed: list[str] = []
    effect: str | None = None
    # affirmative | negative | warning when the reply is a direct answer,
    # else None. Drives Hami's nod or head shake, separate from the text.
    answer: str | None = None
