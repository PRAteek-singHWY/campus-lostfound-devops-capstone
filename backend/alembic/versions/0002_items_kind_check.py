"""add kind/status check constraints

Revision ID: 0002_items_kind_check
Revises: 0001_create_items
Create Date: 2026-10-16
"""
from alembic import op

revision = "0002_items_kind_check"
down_revision = "0001_create_items"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        DO $$ BEGIN
            ALTER TABLE items ADD CONSTRAINT items_kind_check CHECK (kind IN ('lost', 'found'));
        EXCEPTION WHEN duplicate_object THEN NULL; END $$
    """)
    op.execute("""
        DO $$ BEGIN
            ALTER TABLE items ADD CONSTRAINT items_status_check
                CHECK (status IN ('open', 'returned'));
        EXCEPTION WHEN duplicate_object THEN NULL; END $$
    """)


def downgrade():
    op.execute("ALTER TABLE items DROP CONSTRAINT IF EXISTS items_status_check")
    op.execute("ALTER TABLE items DROP CONSTRAINT IF EXISTS items_kind_check")
