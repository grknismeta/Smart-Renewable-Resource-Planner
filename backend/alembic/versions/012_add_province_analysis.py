"""province_analysis + scheduler_meta tablolari (Faz 1 — Tek Kaynak)

Saatlik APScheduler + il x kaynak skorlari icin iki yeni SystemBase tablosu.

- province_analysis: il x (wind/solar/hydro) skorlari + ham metrikler.
  Raporlar, Il Analizi, Onerilen Bolgeler, Choropleth tek kaynak.
- scheduler_meta: job bazli son calisma zamani ("228 dk once" fix).

Revision ID: 012_add_province_analysis
Revises: 011_plate_location_codes
Create Date: 2026-04-19
"""

from alembic import op
import sqlalchemy as sa


revision = '012_add_province_analysis'
down_revision = '011_plate_location_codes'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'province_analysis',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('province_name', sa.String(), nullable=False, index=True),
        sa.Column('resource_type', sa.String(), nullable=False, index=True),
        sa.Column('score_1m', sa.Float(), nullable=True),
        sa.Column('score_3m', sa.Float(), nullable=True),
        sa.Column('score_6m', sa.Float(), nullable=True),
        sa.Column('score_yearly', sa.Float(), nullable=True),
        sa.Column('avg_wind_speed', sa.Float(), nullable=True),
        sa.Column('avg_solar_radiation', sa.Float(), nullable=True),
        sa.Column('avg_temperature', sa.Float(), nullable=True),
        sa.Column('capacity_factor', sa.Float(), nullable=True),
        sa.Column('sample_count', sa.Integer(), nullable=True),
        sa.Column(
            'computed_at',
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            onupdate=sa.func.now(),
        ),
        sa.UniqueConstraint(
            'province_name', 'resource_type', name='uq_province_resource'
        ),
    )
    op.create_index(
        'ix_province_analysis_type_score6m',
        'province_analysis',
        ['resource_type', 'score_6m'],
    )

    op.create_table(
        'scheduler_meta',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('job_name', sa.String(), nullable=False, unique=True, index=True),
        sa.Column('last_run_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('next_run_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_status', sa.String(), nullable=True),
        sa.Column('last_duration_seconds', sa.Float(), nullable=True),
        sa.Column('last_error', sa.Text(), nullable=True),
        sa.Column('run_count', sa.Integer(), server_default='0'),
    )


def downgrade():
    op.drop_table('scheduler_meta')
    op.drop_index('ix_province_analysis_type_score6m', table_name='province_analysis')
    op.drop_table('province_analysis')
