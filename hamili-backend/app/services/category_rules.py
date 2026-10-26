from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.category import Category


def require_category(db: Session, category_id: int, t_type: str) -> Category:
    """The category must exist and match the money direction: an expense
    can't be filed under Salary, and income can't be filed under Food."""
    category = db.get(Category, category_id)
    if category is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Unknown category")
    if category.type != t_type:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"'{category.name}' is an {category.type} category, not {t_type}",
        )
    return category
