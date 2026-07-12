from pydantic import BaseModel


class AnalyticsSummaryOut(BaseModel):
    income: float
    expense: float
    net: float


class CategoryBreakdownOut(BaseModel):
    category_id: int
    total: float


class TrendPointOut(BaseModel):
    year: int
    month: int
    income: float
    expense: float
