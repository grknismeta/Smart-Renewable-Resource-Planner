"""M-E.1 — weather_data precipitation/cloud/humidity kolonları (2026-05-28)

Open-Meteo Historical Archive API'den 2015→bugün backfill için.
scripts/backfill_weather_extras.py yazar.

Revision ID: 020_weather_precip_cloud
Revises: 019_thematic_timeseries
Create Date: 2026-05-28
"""

from alembic import op
import sqlalchemy as sa


revision = '020_weather_precip_cloud'
down_revision = '019_thematic_timeseries'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('weather_data') as batch:
        batch.add_column(sa.Column('precipitation_sum', sa.Float(),
                                   nullable=True,
                                   comment='Günlük yağış toplamı (mm)'))
        batch.add_column(sa.Column('cloud_cover_mean', sa.Float(),
                                   nullable=True,
                                   comment='Günlük bulut örtüsü ortalama (%)'))
        batch.add_column(sa.Column('relative_humidity_mean', sa.Float(),
                                   nullable=True,
                                   comment='Günlük bağıl nem ortalama (%)'))


def downgrade():
    with op.batch_alter_table('weather_data') as batch:
        batch.drop_column('relative_humidity_mean')
        batch.drop_column('cloud_cover_mean')
        batch.drop_column('precipitation_sum')
