"""add scenario pin_ids

Revision ID: 002
Revises: 001
Create Date: 2025-12-18 23:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade():
    # Add pin_ids column (JSON array) to scenarios
    op.add_column('scenarios', sa.Column('pin_ids', sa.JSON(), nullable=True))
    
    # Migrate existing data: convert pin_id to pin_ids array
    op.execute("""
        UPDATE scenarios 
        SET pin_ids = CASE 
            WHEN pin_id IS NOT NULL THEN json_build_array(pin_id)
            ELSE '[]'::json
        END
    """)
    
    # Make pin_id nullable (for new scenarios that only use pin_ids)
    op.alter_column('scenarios', 'pin_id', nullable=True)
    
    # Make start_date and end_date nullable
    op.alter_column('scenarios', 'start_date', nullable=True)
    op.alter_column('scenarios', 'end_date', nullable=True)


def downgrade():
    # Remove pin_ids column
    op.drop_column('scenarios', 'pin_ids')
    
    # Revert pin_id to non-nullable (might fail if there's null data)
    op.alter_column('scenarios', 'pin_id', nullable=False)
    
    # Revert dates to non-nullable
    op.alter_column('scenarios', 'start_date', nullable=False)
    op.alter_column('scenarios', 'end_date', nullable=False)
