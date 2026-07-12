from datetime import datetime

from sqlalchemy import DateTime, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    preferred_name: Mapped[str] = mapped_column(String(100), nullable=False)
    preferred_currency: Mapped[str] = mapped_column(String(10), default="PHP")
    monthly_salary: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)
    allowance: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)
    financial_goal_text: Mapped[str | None] = mapped_column(String(500), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    transactions: Mapped[list["Transaction"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    budgets: Mapped[list["Budget"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    goals: Mapped[list["SavingsGoal"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    recurring_items: Mapped[list["RecurringItem"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    chat_messages: Mapped[list["AIChatMessage"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    insights: Mapped[list["AIInsight"]] = relationship(back_populates="user", cascade="all, delete-orphan")
