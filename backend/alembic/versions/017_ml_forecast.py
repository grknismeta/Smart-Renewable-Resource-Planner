"""ml_forecast — precompute iklim projeksiyonu tablosu

2026-05-28 Sprint M-A — ML İklim Projeksiyonu + Tematik Harita.

İl + ilçe × metrik × senaryo × yıl × ay için önceden hesaplanmış SARIMAX/
Holt-Winters forecast değerleri. Tematik harita + Projeksiyon tab buradan
anında okur (model fit beklemez). Batch: scripts/build_ml_forecasts.py

Revision ID: 017_ml_forecast
Revises: 016_climatology_v3
Create Date: 2026-05-28
"""

from alembic import op
import sqlalchemy as sa


revision = '017_ml_forecast'
down_revision = '016_climatology_v3'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'ml_forecast',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('scope', sa.String(), nullable=False),
        sa.Column('province_name', sa.String(), nullable=False),
        sa.Column('district_name', sa.String(), nullable=True),
        sa.Column('resource', sa.String(), nullable=False),
        sa.Column('metric', sa.String(), nullable=False),
        sa.Column('scenario', sa.String(), nullable=False,
                  server_default='baseline'),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=False),
        sa.Column('value', sa.Float(), nullable=False),
        sa.Column('lower', sa.Float(), nullable=True),
        sa.Column('upper', sa.Float(), nullable=True),
        sa.Column('method', sa.String(), nullable=True),
        sa.Column('mape', sa.Float(), nullable=True),
        sa.Column('computed_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'scope', 'province_name', 'district_name', 'resource',
            'metric', 'scenario', 'year', 'month',
            name='uq_ml_forecast_key',
        ),
    )
    op.create_index('ix_ml_forecast_id', 'ml_forecast', ['id'])
    op.create_index('ix_ml_forecast_scope', 'ml_forecast', ['scope'])
    op.create_index('ix_ml_forecast_province_name', 'ml_forecast',
                    ['province_name'])
    op.create_index('ix_ml_forecast_district_name', 'ml_forecast',
                    ['district_name'])
    op.create_index('ix_ml_forecast_choropleth', 'ml_forecast',
                    ['scope', 'metric', 'scenario', 'year'])
    op.create_index('ix_ml_forecast_location', 'ml_forecast',
                    ['province_name', 'district_name', 'resource', 'metric'])


def downgrade():
    op.drop_index('ix_ml_forecast_location', table_name='ml_forecast')
    op.drop_index('ix_ml_forecast_choropleth', table_name='ml_forecast')
    op.drop_index('ix_ml_forecast_district_name', table_name='ml_forecast')
    op.drop_index('ix_ml_forecast_province_name', table_name='ml_forecast')
    op.drop_index('ix_ml_forecast_scope', table_name='ml_forecast')
    op.drop_index('ix_ml_forecast_id', table_name='ml_forecast')
    op.drop_table('ml_forecast')
