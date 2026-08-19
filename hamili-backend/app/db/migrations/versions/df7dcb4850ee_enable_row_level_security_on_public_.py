"""enable row level security on public tables

Supabase auto-exposes every public-schema table through its PostgREST API,
gated by RLS. This app never uses that API (the backend talks to Postgres
directly via DATABASE_URL, which connects as the privileged role and bypasses
RLS), so enabling RLS with zero policies fully closes that exposed surface
without touching the app's own access.

Revision ID: df7dcb4850ee
Revises: c16c8edb3bb8
Create Date: 2026-08-19 18:27:42.008090

"""
from alembic import op
import sqlalchemy as sa


revision = 'df7dcb4850ee'
down_revision = 'c16c8edb3bb8'
branch_labels = None
depends_on = None

TABLES = [
    'categories',
    'users',
    'ai_chat_messages',
    'ai_insights',
    'budgets',
    'recurring_items',
    'savings_goals',
    'transactions',
    'alembic_version',
]


def upgrade() -> None:
    for table in TABLES:
        op.execute(f'ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;')


def downgrade() -> None:
    for table in TABLES:
        op.execute(f'ALTER TABLE {table} DISABLE ROW LEVEL SECURITY;')
