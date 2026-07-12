from datetime import date

from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.goal import SavingsGoal
from app.models.recurring import RecurringItem
from app.models.transaction import Transaction
from app.models.user import User
from app.services.ai import get_ai_provider


class InsightService:
    """Builds the compact 'financial snapshot' that gives Hami memory of
    the user's situation without fine-tuning — and orchestrates chat /
    proactive insight generation through the active AIProvider."""

    def __init__(self, db: Session):
        self.db = db
        self.provider = get_ai_provider()

    def build_financial_snapshot(self, user: User) -> dict:
        today = date.today()

        recent_transactions = (
            self.db.query(Transaction)
            .filter(Transaction.user_id == user.id)
            .order_by(Transaction.transaction_date.desc())
            .limit(30)
            .all()
        )
        budgets = (
            self.db.query(Budget)
            .filter(Budget.user_id == user.id, Budget.month == today.month, Budget.year == today.year)
            .all()
        )
        goals = self.db.query(SavingsGoal).filter(SavingsGoal.user_id == user.id).all()
        recurring = self.db.query(RecurringItem).filter(RecurringItem.user_id == user.id, RecurringItem.active).all()

        return {
            "preferred_name": user.preferred_name,
            "preferred_currency": user.preferred_currency,
            "financial_goal_text": user.financial_goal_text,
            "recent_transactions": [
                {"amount": float(t.amount), "type": t.type, "category_id": t.category_id, "date": str(t.transaction_date)}
                for t in recent_transactions
            ],
            "budgets": [{"category_id": b.category_id, "limit": float(b.limit_amount)} for b in budgets],
            "goals": [
                {"title": g.title, "target": float(g.target_amount), "current": float(g.current_amount)}
                for g in goals
            ],
            "recurring_items": [
                {"name": r.name, "amount": float(r.amount), "type": r.type, "frequency": r.frequency}
                for r in recurring
            ],
        }

    def chat(self, user: User, message_history: list[dict]) -> str:
        snapshot = self.build_financial_snapshot(user)
        return self.provider.chat(message_history, snapshot)

    def generate_proactive_insights(self, user: User) -> list[str]:
        snapshot = self.build_financial_snapshot(user)
        return self.provider.generate_insights(snapshot)
