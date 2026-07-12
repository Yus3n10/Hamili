from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    preferred_name: str = Field(min_length=1, max_length=100)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    preferred_name: str | None = None
    preferred_currency: str | None = None
    monthly_salary: float | None = None
    allowance: float | None = None
    financial_goal_text: str | None = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    preferred_name: str
    preferred_currency: str
    monthly_salary: float | None
    allowance: float | None
    financial_goal_text: str | None


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
