from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AIInsightOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    insight_type: str
    message: str
    created_at: datetime
