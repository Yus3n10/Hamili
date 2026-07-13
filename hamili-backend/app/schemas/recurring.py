from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class RecurringItemCreate(BaseModel):
    type: str = Field(pattern="^(income|expense)$")
    name: str = Field(min_length=1, max_length=100)
    amount: float = Field(gt=0, le=1_000_000_000_000)
    category_id: int
    frequency: str = Field(pattern="^(weekly|monthly|yearly)$")
    next_due_date: date
    active: bool = True


class RecurringItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    amount: float | None = Field(default=None, gt=0, le=1_000_000_000_000)
    category_id: int | None = None
    frequency: str | None = Field(default=None, pattern="^(weekly|monthly|yearly)$")
    next_due_date: date | None = None
    active: bool | None = None


class RecurringItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str
    name: str
    amount: float
    category_id: int
    frequency: str
    next_due_date: date
    active: bool
