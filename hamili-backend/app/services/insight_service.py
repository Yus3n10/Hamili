from datetime import date

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.ai import AIInsight
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


    def list_active(self, user: User) -> list[AIInsight]:
        """Undismissed insights, newest first."""
        return (
            self.db.query(AIInsight)
            .filter(AIInsight.user_id == user.id, AIInsight.is_read.is_(False))
            .order_by(AIInsight.created_at.desc())
            .all()
        )

    def _has_todays_batch(self, user: User) -> bool:
        """Whether any insight was generated today (read or not) — a batch
        the user has already dismissed still counts, so we don't regenerate
        (and re-charge a Gemini call) the same day."""
        today = date.today()
        return (
            self.db.query(AIInsight)
            .filter(
                AIInsight.user_id == user.id,
                func.date(AIInsight.created_at) == today,
            )
            .first()
            is not None
        )

    def generate_and_store(self, user: User) -> list[AIInsight]:
        """Generate a fresh batch and replace the current unread one. Any
        provider failure (e.g. a dead model id) leaves existing insights
        untouched and returns an empty list rather than raising, so the
        dashboard degrades gracefully instead of erroring."""
        try:
            messages = self.provider.generate_insights(self.build_financial_snapshot(user))
        except Exception:
            return []

        if not messages:
            return []

        self.db.query(AIInsight).filter(
            AIInsight.user_id == user.id, AIInsight.is_read.is_(False)
        ).delete(synchronize_session=False)

        created = [
            AIInsight(user_id=user.id, insight_type="general", message=text)
            for text in messages
            if isinstance(text, str) and text.strip()
        ]
        self.db.add_all(created)
        self.db.commit()
        for insight in created:
            self.db.refresh(insight)
        return created

    def dismiss(self, user: User, insight_id: int) -> None:
        insight = (
            self.db.query(AIInsight)
            .filter(AIInsight.id == insight_id, AIInsight.user_id == user.id)
            .first()
        )
        if not insight:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Insight not found")
        insight.is_read = True
        self.db.commit()


def generate_daily_insights_for(user_id: int) -> None:
    db = SessionLocal()
    try:
        user = db.get(User, user_id)
        if user is None:
            return
        service = InsightService(db)
        if not service._has_todays_batch(user):
            service.generate_and_store(user)
    finally:
        db.close()
