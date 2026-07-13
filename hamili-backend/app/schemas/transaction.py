from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class TransactionCreate(BaseModel):
    category_id: int
    amount: float = Field(gt=0, le=1_000_000_000_000)
    type: str = Field(pattern="^(income|expense)$")
    note: str | None = Field(default=None, max_length=500)
    transaction_date: date


class TransactionUpdate(BaseModel):
    category_id: int | None = None
    amount: float | None = Field(default=None, gt=0, le=1_000_000_000_000)
    note: str | None = Field(default=None, max_length=500)
    transaction_date: date | None = None


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    category_id: int
    amount: float
    type: str
    note: str | None
    transaction_date: date
