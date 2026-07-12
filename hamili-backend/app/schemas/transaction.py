from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class TransactionCreate(BaseModel):
    category_id: int
    amount: float = Field(gt=0)
    type: str = Field(pattern="^(income|expense)$")
    note: str | None = None
    transaction_date: date


class TransactionUpdate(BaseModel):
    category_id: int | None = None
    amount: float | None = Field(default=None, gt=0)
    note: str | None = None
    transaction_date: date | None = None


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    category_id: int
    amount: float
    type: str
    note: str | None
    transaction_date: date
