"""thematic_aggregate — precompute tematik harita pencereleri

2026-05-28 — Ağır tematik modlar (sixMonth/yearly/season/twoYear/fiveYear/
tenYear) için aylık precompute tablosu. build_thematic_aggregates.py doldurur.

Revision ID: 018_thematic_aggregate
Revises: 017_ml_forecast
Create Date: 2026-05-28
"""

from alembic import op
import sqlalchemy as sa


revision = '018_thematic_aggregate'
down_revision = '017_ml_forecast'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'thematic_aggregate',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('scope', sa.String(), nullable=False),
        sa.Column('location_key', sa.String(), nullable=False),
        sa.Column('metric', sa.String(), nullable=False),
        sa.Column('mode', sa.String(), nullable=False),
        sa.Column('season', sa.String(), nullable=False, server_default='-'),
        sa.Column('value', sa.Float(), nullable=True),
        sa.Column('sample_count', sa.Integer(), nullable=True),
        sa.Column('source', sa.String(), nullable=True),
        sa.Column('computed_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'scope', 'location_key', 'metric', 'mode', 'season',
            name='uq_thematic_aggregate_key',
        ),
    )
    op.create_index('ix_thematic_aggregate_id', 'thematic_aggregate', ['id'])
    op.create_index('ix_thematic_aggregate_scope', 'thematic_aggregate',
                    ['scope'])
    op.create_index('ix_thematic_aggregate_location_key', 'thematic_aggregate',
                    ['location_key'])
    op.create_index('ix_thematic_aggregate_lookup', 'thematic_aggregate',
                    ['scope', 'metric', 'mode', 'season'])


def downgrade():
    op.drop_index('ix_thematic_aggregate_lookup', table_name='thematic_aggregate')
    op.drop_index('ix_thematic_aggregate_location_key',
                  table_name='thematic_aggregate')
    op.drop_index('ix_thematic_aggregate_scope', table_name='thematic_aggregate')
    op.drop_index('ix_thematic_aggregate_id', table_name='thematic_aggregate')
    op.drop_table('thematic_aggregate')
