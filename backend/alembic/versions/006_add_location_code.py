"""Add location_code column to hourly_weather_data

Her il/ilçe kaydına sabit bir konum kodu (ör. 'ist0', 'ist14') ekler.
Türkçe karakter/ASCII uyuşmazlıklarını ve isim farklarını ortadan kaldırır.

Revision ID: 006_add_location_code
Revises: 005_fix_district_city_name
Create Date: 2026-03-21
"""
from alembic import op
import sqlalchemy as sa

revision = '006_add_location_code'
down_revision = '005_fix_district_city_name'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'hourly_weather_data',
        sa.Column('location_code', sa.String(10), nullable=True),
    )
    op.create_index(
        'ix_hourly_weather_data_location_code',
        'hourly_weather_data',
        ['location_code'],
    )


def downgrade():
    op.drop_index('ix_hourly_weather_data_location_code', table_name='hourly_weather_data')
    op.drop_column('hourly_weather_data', 'location_code')
