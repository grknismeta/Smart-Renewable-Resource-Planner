"""rename title to name in pins table

Revision ID: 001
Revises: 
Create Date: 2024-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename title column to name
    try:
        op.alter_table('pins', schema=None)
        op.drop_column('pins', 'title')
        op.add_column('pins', sa.Column('name', sa.String(), nullable=True))
    except Exception as e:
        print(f"Migration warning: {e}")
        # If column doesn't exist or already renamed, continue


def downgrade() -> None:
    # This migration is not reversible in a clean way
    pass
