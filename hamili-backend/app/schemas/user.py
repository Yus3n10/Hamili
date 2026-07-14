from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    preferred_name: str = Field(min_length=1, max_length=100)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    preferred_name: str | None = Field(default=None, min_length=1, max_length=100)
    preferred_currency: str | None = Field(default=None, min_length=1, max_length=8)
    monthly_salary: float | None = Field(default=None, ge=0, le=1_000_000_000_000)
    allowance: float | None = Field(default=None, ge=0, le=1_000_000_000_000)
    financial_goal_text: str | None = Field(default=None, max_length=500)


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


class TokenRefresh(BaseModel):
    refresh_token: str
