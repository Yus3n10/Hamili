from datetime import date

from sqlalchemy.orm import Session

from app.models.recurring import RecurringItem


class RecurringRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: int) -> list[RecurringItem]:
        return (
            self.db.query(RecurringItem)
            .filter(RecurringItem.user_id == user_id)
            .order_by(RecurringItem.next_due_date.asc())
            .all()
        )

    def get(self, item_id: int, user_id: int) -> RecurringItem | None:
        return (
            self.db.query(RecurringItem)
            .filter(RecurringItem.id == item_id, RecurringItem.user_id == user_id)
            .first()
        )

    def list_due(self, user_id: int, today: date) -> list[RecurringItem]:
        return (
            self.db.query(RecurringItem)
            .filter(
                RecurringItem.user_id == user_id,
                RecurringItem.active.is_(True),
                RecurringItem.next_due_date <= today,
            )
            .all()
        )

    def create(self, item: RecurringItem) -> RecurringItem:
        self.db.add(item)
        self.db.commit()
        self.db.refresh(item)
        return item

    def save(self, item: RecurringItem) -> RecurringItem:
        self.db.commit()
        self.db.refresh(item)
        return item

    def delete(self, item: RecurringItem) -> None:
        self.db.delete(item)
        self.db.commit()
