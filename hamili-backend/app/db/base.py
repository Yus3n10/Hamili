"""
Declarative base shared by every ORM model.

Alembic's env.py imports Base.metadata from here, and every model module
imports Base from here — this is what lets `alembic revision --autogenerate`
see the full schema.
"""

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
