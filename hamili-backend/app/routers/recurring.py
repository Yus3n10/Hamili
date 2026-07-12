from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.recurring import RecurringItemCreate, RecurringItemOut, RecurringItemUpdate
from app.services.recurring_service import RecurringService

router = APIRouter(prefix="/recurring", tags=["recurring"])


@router.get("", response_model=list[RecurringItemOut])
def list_recurring(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = RecurringService(db)
    service.promote_due(current_user)  # catch up any due items before returning the list
    return service.list(current_user)


@router.post("", response_model=RecurringItemOut, status_code=201)
def create_recurring(
    payload: RecurringItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return RecurringService(db).create(current_user, payload)


@router.patch("/{item_id}", response_model=RecurringItemOut)
def update_recurring(
    item_id: int,
    payload: RecurringItemUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return RecurringService(db).update(current_user, item_id, payload)


@router.delete("/{item_id}", status_code=204)
def delete_recurring(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    RecurringService(db).delete(current_user, item_id)


@router.post("/run-due")
def run_due(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    promoted = RecurringService(db).promote_due(current_user)
    return {"promoted": promoted}
