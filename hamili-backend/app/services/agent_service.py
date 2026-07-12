"""
Turns natural-language chat into real actions ("add a savings goal…",
"change my preferred name to Yusen"). The AI provider interprets the message
into a structured action; this service executes it against the existing
domain services and reports which parts of the app changed so the client can
refresh the right tabs.
"""

from datetime import date

from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.goal import SavingsGoal
from app.models.user import User
from app.schemas.budget import BudgetCreate
from app.schemas.goal import GoalContribution, SavingsGoalCreate, SavingsGoalUpdate
from app.schemas.recurring import RecurringItemCreate
from app.schemas.transaction import TransactionCreate
from app.schemas.user import UserUpdate
from app.services.ai import get_ai_provider
from app.services.auth_service import AuthService
from app.services.budget_service import BudgetService
from app.services.goal_service import GoalService
from app.services.insight_service import InsightService
from app.services.recurring_service import RecurringService
from app.services.transaction_service import TransactionService


class AgentService:
    def __init__(self, db: Session):
        self.db = db
        self.provider = get_ai_provider()

    def respond(self, user: User, message_history: list[dict]) -> dict:
        """Returns {"reply": str, "changed": list[str]} — `changed` names the
        app areas the client should refresh (goals/budgets/transactions/profile)."""
        snapshot = InsightService(self.db).build_financial_snapshot(user)
        category_names = [c.name for c in self.db.query(Category).all()]
        result = self.provider.interpret(message_history, snapshot, category_names, date.today().isoformat())

        action = (result.get("action") or "none").strip()
        params = result.get("params") or {}
        reply = (result.get("reply") or "").strip() or "Done!"

        if action == "none":
            return {"reply": reply, "changed": []}

        try:
            changed = self._execute(user, action, params)
        except Exception:  # noqa: BLE001 — don't claim success if execution failed
            self.db.rollback()  # clear the poisoned session so the caller can still commit
            return {
                "reply": "I couldn't quite complete that — mind trying again with a little more detail?",
                "changed": [],
            }
        return {"reply": reply, "changed": changed}

    def _execute(self, user: User, action: str, params: dict) -> list[str]:
        if action == "add_savings_goal":
            GoalService(self.db).create(
                user,
                SavingsGoalCreate(
                    title=params["title"],
                    target_amount=float(params["target_amount"]),
                    target_date=params.get("target_date") or None,
                ),
            )
            return ["goals"]

        if action == "edit_savings_goal":
            goal = self._find_goal(user, params.get("title"))
            # Only include fields the user actually gave, so unspecified ones
            # (which arrive as null) don't overwrite the existing goal.
            updates: dict = {}
            if params.get("new_title") is not None:
                updates["title"] = params["new_title"]
            if params.get("target_amount") is not None:
                updates["target_amount"] = params["target_amount"]
            if params.get("target_date") is not None:
                updates["target_date"] = params["target_date"]
            GoalService(self.db).update(user, goal.id, SavingsGoalUpdate(**updates))
            return ["goals"]

        if action == "delete_savings_goal":
            goal = self._find_goal(user, params.get("title"))
            GoalService(self.db).delete(user, goal.id)
            return ["goals"]

        if action == "contribute_to_goal":
            goal = self._find_goal(user, params.get("title"))
            GoalService(self.db).contribute(user, goal.id, GoalContribution(amount=float(params["amount"])))
            return ["goals"]

        if action == "add_recurring_item":
            t_type = params.get("type", "expense")
            category_id = self._match_category(params.get("category"), t_type)
            RecurringService(self.db).create(
                user,
                RecurringItemCreate(
                    type=t_type,
                    name=params["name"],
                    amount=float(params["amount"]),
                    category_id=category_id,
                    frequency=params.get("frequency", "monthly"),
                    next_due_date=params.get("next_due_date") or date.today().isoformat(),
                ),
            )
            return ["recurring"]

        if action == "set_budget":
            category_id = self._match_category(params.get("category"), "expense")
            today = date.today()
            BudgetService(self.db).create_or_update(
                user,
                BudgetCreate(
                    category_id=category_id,
                    month=today.month,
                    year=today.year,
                    limit_amount=float(params["limit_amount"]),
                ),
            )
            return ["budgets"]

        if action == "add_transaction":
            t_type = params.get("type", "expense")
            category_id = self._match_category(params.get("category"), t_type)
            TransactionService(self.db).create(
                user,
                TransactionCreate(
                    category_id=category_id,
                    amount=float(params["amount"]),
                    type=t_type,
                    note=params.get("note") or None,
                    transaction_date=params.get("date") or date.today().isoformat(),
                ),
            )
            # An expense changes its category's budget usage, so the client
            # must refresh budgets too — not just the transactions list.
            return ["transactions", "budgets"] if t_type == "expense" else ["transactions"]

        if action == "update_profile":
            AuthService(self.db).update_profile(
                user,
                UserUpdate(
                    preferred_name=params.get("preferred_name"),
                    preferred_currency=params.get("preferred_currency"),
                    financial_goal_text=params.get("financial_goal_text"),
                ),
            )
            return ["profile"]

        return []

    def _find_goal(self, user: User, title: str | None) -> SavingsGoal:
        goals = self.db.query(SavingsGoal).filter(SavingsGoal.user_id == user.id).all()
        title_l = (title or "").lower().strip()
        for g in goals:
            if g.title.lower() == title_l:
                return g
        for g in goals:
            if title_l and (title_l in g.title.lower() or g.title.lower() in title_l):
                return g
        raise ValueError("goal not found")

    def _match_category(self, name: str | None, t_type: str) -> int:
        cats = [c for c in self.db.query(Category).all() if c.type == t_type]
        name_l = (name or "").lower().strip()
        for c in cats:
            if c.name.lower() == name_l:
                return c.id
        for c in cats:
            if name_l and (name_l in c.name.lower() or c.name.lower() in name_l):
                return c.id
        for c in cats:
            if c.name.lower() == "others":
                return c.id
        if cats:
            return cats[0].id
        raise ValueError("no category available")
