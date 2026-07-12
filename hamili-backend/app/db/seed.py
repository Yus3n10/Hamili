"""
Seeds the default categories listed in the product spec. Run once after
migrations: `python -m app.db.seed`
Safe to re-run — skips categories that already exist by name.
"""

from app.db.session import SessionLocal
from app.models.category import Category

DEFAULT_CATEGORIES = [
    ("Food", "expense", "restaurant"),
    ("Transportation", "expense", "directions_car"),
    ("Shopping", "expense", "shopping_bag"),
    ("Bills", "expense", "receipt"),
    ("Entertainment", "expense", "movie"),
    ("Health", "expense", "favorite"),
    ("Education", "expense", "school"),
    ("Others", "expense", "category"),
    ("Salary", "income", "payments"),
    ("Allowance", "income", "wallet"),
    ("Freelance", "income", "work"),
    ("Investment", "income", "trending_up"),
]


def seed() -> None:
    db = SessionLocal()
    try:
        existing_names = {c.name for c in db.query(Category).all()}
        for name, type_, icon in DEFAULT_CATEGORIES:
            if name not in existing_names:
                db.add(Category(name=name, type=type_, icon=icon, is_default=True))
        db.commit()
        print(f"Seeded {len(DEFAULT_CATEGORIES) - len(existing_names)} new categories.")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
