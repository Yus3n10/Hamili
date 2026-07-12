"""
Importing every model here ensures Alembic's autogenerate can see the full
schema via Base.metadata, regardless of which module triggers the import.
"""

from app.models.ai import AIChatMessage, AIInsight
from app.models.budget import Budget
from app.models.category import Category
from app.models.goal import SavingsGoal
from app.models.recurring import RecurringItem
from app.models.transaction import Transaction
from app.models.user import User

__all__ = [
    "User",
    "Category",
    "Transaction",
    "Budget",
    "SavingsGoal",
    "RecurringItem",
    "AIChatMessage",
    "AIInsight",
]
