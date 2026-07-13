from datetime import date

from pydantic import BaseModel, Field


class SavingsGoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    target_amount: float = Field(gt=0, le=1_000_000_000_000)
    target_date: date | None = None


class SavingsGoalUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=150)
    target_amount: float | None = Field(default=None, gt=0, le=1_000_000_000_000)
    target_date: date | None = None


class GoalContribution(BaseModel):
    amount: float = Field(gt=0, le=1_000_000_000_000)


class SavingsGoalOut(BaseModel):
    id: int
    title: str
    target_amount: float
    current_amount: float
    remaining_amount: float
    progress_percentage: float
    target_date: date | None
    estimated_completion_date: date | None
    status: str
