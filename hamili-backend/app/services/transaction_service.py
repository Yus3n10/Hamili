from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.transaction import Transaction
from app.models.user import User
from app.repositories.transaction_repository import TransactionRepository
from app.schemas.transaction import TransactionCreate, TransactionUpdate


class TransactionService:
    def __init__(self, db: Session):
        self.repo = TransactionRepository(db)

    def list(self, user: User, category_id: int | None, search: str | None):
        return self.repo.list_for_user(user.id, category_id, search)

    def create(self, user: User, payload: TransactionCreate) -> Transaction:
        transaction = Transaction(user_id=user.id, **payload.model_dump())
        return self.repo.create(transaction)

    def update(self, user: User, transaction_id: int, payload: TransactionUpdate) -> Transaction:
        transaction = self._get_owned(user, transaction_id)
        return self.repo.update(transaction, **payload.model_dump(exclude_unset=True))

    def delete(self, user: User, transaction_id: int) -> None:
        transaction = self._get_owned(user, transaction_id)
        self.repo.delete(transaction)

    def _get_owned(self, user: User, transaction_id: int) -> Transaction:
        transaction = self.repo.get(transaction_id, user.id)
        if not transaction:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Transaction not found")
        return transaction
