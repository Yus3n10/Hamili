"""admin console tracking: last_active_at, activity days, AI usage, admin access log

The new tables get row level security with no policies, like every other
public table (see df7dcb4850ee): the backend connects as the privileged role,
and Supabase's PostgREST API must not expose them.

Revision ID: a1d3c0nsole01
Revises: df7dcb4850ee
Create Date: 2026-10-27 09:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'a1d3c0nsole01'
down_revision = 'df7dcb4850ee'
branch_labels = None
depends_on = None

NEW_TABLES = ['user_activity_days', 'ai_usage_events', 'admin_access_log']


def _is_postgres() -> bool:
    return op.get_context().dialect.name == 'postgresql'


def upgrade() -> None:
    op.add_column('users', sa.Column('last_active_at', sa.DateTime(timezone=True), nullable=True))

    op.create_table('user_activity_days',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('day', sa.Date(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'day', name='uq_user_activity_day')
    )
    op.create_index(op.f('ix_user_activity_days_user_id'), 'user_activity_days', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_activity_days_day'), 'user_activity_days', ['day'], unique=False)

    op.create_table('ai_usage_events',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('kind', sa.String(length=20), nullable=False),
    sa.Column('model', sa.String(length=100), nullable=True),
    sa.Column('prompt_tokens', sa.Integer(), nullable=True),
    sa.Column('output_tokens', sa.Integer(), nullable=True),
    sa.Column('total_tokens', sa.Integer(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_ai_usage_events_user_id'), 'ai_usage_events', ['user_id'], unique=False)
    op.create_index(op.f('ix_ai_usage_events_created_at'), 'ai_usage_events', ['created_at'], unique=False)

    op.create_table('admin_access_log',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('admin_user_id', sa.Integer(), nullable=False),
    sa.Column('path', sa.String(length=200), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['admin_user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_admin_access_log_admin_user_id'), 'admin_access_log', ['admin_user_id'], unique=False)
    op.create_index(op.f('ix_admin_access_log_created_at'), 'admin_access_log', ['created_at'], unique=False)

    if _is_postgres():
        for table in NEW_TABLES:
            op.execute(f'ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;')


def downgrade() -> None:
    op.drop_index(op.f('ix_admin_access_log_created_at'), table_name='admin_access_log')
    op.drop_index(op.f('ix_admin_access_log_admin_user_id'), table_name='admin_access_log')
    op.drop_table('admin_access_log')
    op.drop_index(op.f('ix_ai_usage_events_created_at'), table_name='ai_usage_events')
    op.drop_index(op.f('ix_ai_usage_events_user_id'), table_name='ai_usage_events')
    op.drop_table('ai_usage_events')
    op.drop_index(op.f('ix_user_activity_days_day'), table_name='user_activity_days')
    op.drop_index(op.f('ix_user_activity_days_user_id'), table_name='user_activity_days')
    op.drop_table('user_activity_days')
    op.drop_column('users', 'last_active_at')
