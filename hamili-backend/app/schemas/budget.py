from pydantic import BaseModel, Field


class BudgetCreate(BaseModel):
    """POST /budgets is an upsert — creating a budget for a category/month/
    year that already has one updates the existing row instead of erroring,
    since 'set my Food budget to ₱3000' should just work whether or not
    you'd set it before."""

    category_id: int
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2020, le=2100)
    limit_amount: float = Field(gt=0, le=1_000_000_000_000)


class BudgetUpdate(BaseModel):
    limit_amount: float = Field(gt=0, le=1_000_000_000_000)


class BudgetOut(BaseModel):
    id: int
    category_id: int
    month: int
    year: int
    limit_amount: float
    spent_amount: float
    remaining_amount: float
    percentage_used: float
