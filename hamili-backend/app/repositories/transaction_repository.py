from sqlalchemy.orm import Session

from app.models.transaction import Transaction


class TransactionRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: int, category_id: int | None = None, search: str | None = None):
        query = self.db.query(Transaction).filter(Transaction.user_id == user_id)
        if category_id:
            query = query.filter(Transaction.category_id == category_id)
        if search:
            query = query.filter(Transaction.note.ilike(f"%{search}%"))
        return query.order_by(Transaction.transaction_date.desc()).all()

    def get(self, transaction_id: int, user_id: int) -> Transaction | None:
        return (
            self.db.query(Transaction)
            .filter(Transaction.id == transaction_id, Transaction.user_id == user_id)
            .first()
        )

    def create(self, transaction: Transaction) -> Transaction:
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def update(self, transaction: Transaction, **fields) -> Transaction:
        for key, value in fields.items():
            if value is not None:
                setattr(transaction, key, value)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def delete(self, transaction: Transaction) -> None:
        self.db.delete(transaction)
        self.db.commit()
