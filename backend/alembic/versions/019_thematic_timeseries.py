"""thematic_timeseries — zaman simülasyonu uzun pencere frame precompute

2026-05-28 (T-6) — 2y/5y/10y haftalık/aylık zaman simülasyonu frame'leri.
build_thematic_timeseries.py doldurur (date_trunc GROUP BY).

Revision ID: 019_thematic_timeseries
Revises: 018_thematic_aggregate
Create Date: 2026-05-28
"""

from alembic import op
import sqlalchemy as sa


revision = '019_thematic_timeseries'
down_revision = '018_thematic_aggregate'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'thematic_timeseries',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('scope', sa.String(), nullable=False),
        sa.Column('location_key', sa.String(), nullable=False),
        sa.Column('metric', sa.String(), nullable=False),
        sa.Column('period_type', sa.String(), nullable=False),
        sa.Column('period_start', sa.Date(), nullable=False),
        sa.Column('value', sa.Float(), nullable=True),
        sa.Column('source', sa.String(), nullable=True),
        sa.Column('computed_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'scope', 'location_key', 'metric', 'period_type', 'period_start',
            name='uq_thematic_timeseries_key',
        ),
    )
    op.create_index('ix_thematic_timeseries_id', 'thematic_timeseries', ['id'])
    op.create_index('ix_thematic_timeseries_scope', 'thematic_timeseries',
                    ['scope'])
    op.create_index('ix_thematic_timeseries_location_key',
                    'thematic_timeseries', ['location_key'])
    op.create_index('ix_thematic_timeseries_period_start',
                    'thematic_timeseries', ['period_start'])
    op.create_index('ix_thematic_timeseries_lookup', 'thematic_timeseries',
                    ['scope', 'metric', 'period_type', 'period_start'])


def downgrade():
    op.drop_index('ix_thematic_timeseries_lookup',
                  table_name='thematic_timeseries')
    op.drop_index('ix_thematic_timeseries_period_start',
                  table_name='thematic_timeseries')
    op.drop_index('ix_thematic_timeseries_location_key',
                  table_name='thematic_timeseries')
    op.drop_index('ix_thematic_timeseries_scope',
                  table_name='thematic_timeseries')
    op.drop_index('ix_thematic_timeseries_id',
                  table_name='thematic_timeseries')
    op.drop_table('thematic_timeseries')
