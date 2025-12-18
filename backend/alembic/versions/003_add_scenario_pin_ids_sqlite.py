"""add scenario pin_ids for SQLite

Revision ID: 003
Revises: 002
Create Date: 2025-12-18 15:35:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None


def upgrade():
    # SQLite için pin_ids kolonunu ekle
    with op.batch_alter_table('scenarios', schema=None) as batch_op:
        batch_op.add_column(sa.Column('pin_ids', sa.JSON(), nullable=True))
    
    # Mevcut verileri migrate et: pin_id -> pin_ids array
    connection = op.get_bind()
    connection.execute(sa.text("""
        UPDATE scenarios 
        SET pin_ids = CASE 
            WHEN pin_id IS NOT NULL THEN json_array(pin_id)
            ELSE '[]'
        END
        WHERE pin_ids IS NULL
    """))


def downgrade():
    with op.batch_alter_table('scenarios', schema=None) as batch_op:
        batch_op.drop_column('pin_ids')
