"""Add composite indexes to hourly_weather_data for query performance.

Pattern analysis of weather.py shows these filter combinations are used heavily:
  - (city_name, timestamp)                     → /summary, /cities/{name}/hourly
  - (city_name, district_name, timestamp)      → /summary N+1 loop (soon to be removed)
  - (timestamp, district_name)                 → /animation hourly, /at-time
  - (location_code, timestamp)                 → /district-summary

Revision ID: 009_composite_indexes
Revises: 008_norm_city_names
Create Date: 2026-03-22
"""

from alembic import op

revision = '009_composite_indexes'
down_revision = '008_norm_city_names'
branch_labels = None
depends_on = None


def upgrade():
    # (city_name, timestamp) DESC — en sık kullanılan filtre kombinasyonu
    op.create_index(
        'idx_hourly_city_ts',
        'hourly_weather_data',
        ['city_name', 'timestamp'],
        postgresql_ops={'timestamp': 'DESC'},
    )

    # (city_name, district_name, timestamp) — district filtreli sorgular
    op.create_index(
        'idx_hourly_city_district_ts',
        'hourly_weather_data',
        ['city_name', 'district_name', 'timestamp'],
    )

    # (timestamp, district_name) — animasyon + at-time sorgular
    op.create_index(
        'idx_hourly_ts_district',
        'hourly_weather_data',
        ['timestamp', 'district_name'],
    )

    # (location_code, timestamp) — location_code tabanlı district sorgular
    op.create_index(
        'idx_hourly_loccode_ts',
        'hourly_weather_data',
        ['location_code', 'timestamp'],
    )


def downgrade():
    op.drop_index('idx_hourly_city_ts',         table_name='hourly_weather_data')
    op.drop_index('idx_hourly_city_district_ts', table_name='hourly_weather_data')
    op.drop_index('idx_hourly_ts_district',      table_name='hourly_weather_data')
    op.drop_index('idx_hourly_loccode_ts',       table_name='hourly_weather_data')
