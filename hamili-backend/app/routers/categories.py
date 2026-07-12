from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.category import Category
from app.models.user import User
from app.schemas.category import CategoryOut

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
def list_categories(
    type: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Categories are global (seeded), not per-user — but this stays behind
    auth like everything else, and `type` lets the client ask for just
    income or just expense categories when building a picker."""
    query = db.query(Category)
    if type:
        query = query.filter(Category.type == type)
    return query.order_by(Category.name).all()
