"""add district_name to hourly_weather_data

Revision ID: 004_add_district_name
Revises: 003_add_scenario_pin_ids_sqlite
Create Date: 2025-12-25

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '004_add_district_name'
down_revision = '003_add_scenario_pin_ids_sqlite'
branch_labels = None
depends_on = None


def upgrade():
    # SQLite için ALTER TABLE ADD COLUMN
    with op.batch_alter_table('hourly_weather_data', schema=None) as batch_op:
        batch_op.add_column(sa.Column('district_name', sa.String(), nullable=True))
        batch_op.create_index('ix_hourly_weather_data_district_name', ['district_name'])


def downgrade():
    with op.batch_alter_table('hourly_weather_data', schema=None) as batch_op:
        batch_op.drop_index('ix_hourly_weather_data_district_name')
        batch_op.drop_column('district_name')
