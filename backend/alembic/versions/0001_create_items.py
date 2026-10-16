"""create items table

Revision ID: 0001_create_items
Revises:
Create Date: 2026-10-16
"""
from alembic import op

revision = "0001_create_items"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # IF NOT EXISTS keeps the migration idempotent on databases created before Alembic was added
    op.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id SERIAL PRIMARY KEY,
            title TEXT NOT NULL,
            location TEXT NOT NULL,
            kind TEXT NOT NULL DEFAULT 'lost',
            status TEXT NOT NULL DEFAULT 'open',
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS items_status_idx ON items (status)")


def downgrade():
    op.execute("DROP INDEX IF EXISTS items_status_idx")
    op.execute("DROP TABLE IF EXISTS items")
