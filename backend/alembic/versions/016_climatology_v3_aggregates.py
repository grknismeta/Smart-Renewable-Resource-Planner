"""climatology v3 aggregates — wind rose, precip, cloud, sunshine, river discharge

2026-05-20 Sprint R1 — Reports v3 (Landing-first hiyerarşi).

climatology tablosuna 5 yeni JSON kolon eklenir. v3 raporlar için
gereken aylık seriler (Open-Meteo'dan R0 Colab çekiyor):

- `wind_direction_histogram` JSON   — 8 yön × 13 ay (0=yıllık) × {freq_pct}
- `monthly_precipitation` JSON      — 12 ay × ortalama mm (10 yıl ort.)
- `monthly_cloud_cover` JSON        — 12 ay × ortalama %
- `monthly_sunshine_hours` JSON     — 12 ay × ortalama saat/ay
- `monthly_river_discharge` JSON    — 12 ay × {mean, min, max} m³/s

Bu kolonlar, mevcut climatology felsefesine uygun olarak **statik** kalır
(6 ayda bir refresh job ile güncellenir). Pin-level live debi ise pin
metadata'sına yazılır (climatology tablosuna girmez).

CSV import script'i: backend/scripts/import_colab_csvs.py

Revision ID: 016_climatology_v3
Revises: 015_climatology_pin_install
Create Date: 2026-05-20
"""

from alembic import op
import sqlalchemy as sa


revision = '016_climatology_v3'
down_revision = '015_climatology_pin_install'
branch_labels = None
depends_on = None


def upgrade():
    # PostgreSQL JSON kolonları — climatology zaten JSON kullanıyor
    # (hourly_typical_profile), aynı pattern.
    with op.batch_alter_table('climatology') as batch:
        batch.add_column(sa.Column(
            'wind_direction_histogram', sa.JSON(), nullable=True,
            comment='8 yön × 13 ay (0=yıllık) frekans % - R0 Colab/wind_direction_histogram.csv',
        ))
        batch.add_column(sa.Column(
            'monthly_precipitation', sa.JSON(), nullable=True,
            comment='12 ay × ortalama mm (10 yıl ort.) - R0 Colab/climate_monthly.csv',
        ))
        batch.add_column(sa.Column(
            'monthly_cloud_cover', sa.JSON(), nullable=True,
            comment='12 ay × ortalama % - R0 Colab/monthly_cloud_cover.csv',
        ))
        batch.add_column(sa.Column(
            'monthly_sunshine_hours', sa.JSON(), nullable=True,
            comment='12 ay × ortalama saat/ay - R0 Colab/climate_monthly.csv',
        ))
        batch.add_column(sa.Column(
            'monthly_river_discharge', sa.JSON(), nullable=True,
            comment='12 ay × {mean,min,max} m³/s - R0 Colab/river_discharge_monthly.csv',
        ))


def downgrade():
    with op.batch_alter_table('climatology') as batch:
        batch.drop_column('monthly_river_discharge')
        batch.drop_column('monthly_sunshine_hours')
        batch.drop_column('monthly_cloud_cover')
        batch.drop_column('monthly_precipitation')
        batch.drop_column('wind_direction_histogram')
