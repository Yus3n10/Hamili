from calendar import monthrange
from datetime import date, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.recurring import RecurringItem
from app.models.transaction import Transaction
from app.models.user import User
from app.repositories.recurring_repository import RecurringRepository
from app.schemas.recurring import RecurringItemCreate, RecurringItemUpdate

MAX_BACKFILL_PERIODS = 60


def _add_months(d: date, months: int) -> date:
    total = d.month - 1 + months
    year = d.year + total // 12
    month = total % 12 + 1
    last_day = monthrange(year, month)[1]
    return date(year, month, min(d.day, last_day))


def advance_date(d: date, frequency: str) -> date:
    """Next occurrence after `d`. Monthly/yearly clamp the day to the
    target month's length (Jan 31 -> Feb 28), which means an item that
    starts on the 29th-31st drifts to the 28th once it passes February.
    This is an accepted limitation — the model stores no anchor day."""
    if frequency == "weekly":
        return d + timedelta(days=7)
    if frequency == "monthly":
        return _add_months(d, 1)
    if frequency == "yearly":
        return _add_months(d, 12)
    raise ValueError(f"Unknown frequency: {frequency}")


class RecurringService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = RecurringRepository(db)

    def list(self, user: User) -> list[RecurringItem]:
        return self.repo.list_for_user(user.id)

    def create(self, user: User, payload: RecurringItemCreate) -> RecurringItem:
        item = RecurringItem(user_id=user.id, **payload.model_dump())
        return self.repo.create(item)

    def update(self, user: User, item_id: int, payload: RecurringItemUpdate) -> RecurringItem:
        item = self._get_owned(user, item_id)
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(item, field, value)
        return self.repo.save(item)

    def delete(self, user: User, item_id: int) -> None:
        item = self._get_owned(user, item_id)
        self.repo.delete(item)

    def promote_due(self, user: User, today: date | None = None) -> int:
        """Turn every past-due active item into real Transaction rows, one
        per missed period at that period's real date, advancing the item's
        next_due_date past today. Idempotent: a second call the same day is
        a no-op because next_due_date is now in the future."""
        today = today or date.today()
        promoted = 0
        for item in self.repo.list_due(user.id, today):
            count = 0
            while item.next_due_date <= today and count < MAX_BACKFILL_PERIODS:
                self.db.add(
                    Transaction(
                        user_id=user.id,
                        category_id=item.category_id,
                        amount=item.amount,
                        type=item.type,
                        note=item.name,
                        transaction_date=item.next_due_date,
                    )
                )
                item.next_due_date = advance_date(item.next_due_date, item.frequency)
                count += 1
                promoted += 1
            while item.next_due_date <= today:
                item.next_due_date = advance_date(item.next_due_date, item.frequency)
        self.db.commit()
        return promoted

    def _get_owned(self, user: User, item_id: int) -> RecurringItem:
        item = self.repo.get(item_id, user.id)
        if not item:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Recurring item not found")
        return item
