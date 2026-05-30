"""pin advanced params + equipments.owner_id (user-aware ekipman)

2026-05-17 Sprint A — Pin Gelişmiş Ayarlar backend desteği.

Pin tablosuna manuel parametre alanları:
  GES: panel_tilt, panel_azimuth, panel_power_w
  RES: hub_height, rotor_diameter, rated_power_kw
  (HES alanları — flow_rate/head_height/basin_area_km2 — zaten var)

Equipments tablosuna owner_id (nullable):
  NULL → sistem ekipmanı (varsayılan kütüphane)
  Dolu → kullanıcının kendi eklediği ekipman (sadece kendi görür)

Revision ID: 013_pin_advanced_params
Revises: 012_add_province_analysis
Create Date: 2026-05-17
"""

from alembic import op
import sqlalchemy as sa


revision = '013_pin_advanced_params'
down_revision = '012_add_province_analysis'
branch_labels = None
depends_on = None


def upgrade():
    # ── Pin tablosu: GES advanced ────────────────────────────────────────
    op.add_column('pins', sa.Column('panel_tilt', sa.Float(), nullable=True))
    op.add_column('pins', sa.Column('panel_azimuth', sa.Float(), nullable=True))
    op.add_column('pins', sa.Column('panel_power_w', sa.Float(), nullable=True))

    # ── Pin tablosu: RES advanced ────────────────────────────────────────
    op.add_column('pins', sa.Column('hub_height', sa.Float(), nullable=True))
    op.add_column('pins', sa.Column('rotor_diameter', sa.Float(), nullable=True))
    op.add_column('pins', sa.Column('rated_power_kw', sa.Float(), nullable=True))

    # ── Equipments tablosuna owner_id (nullable) ─────────────────────────
    # NULL = sistem ekipmanı (varsayılan kütüphane), dolu = user-specific.
    # FK kurmuyoruz çünkü Equipment SystemBase'de, User UserBase'de farklı
    # şemada olabiliyor (sqlite tek db'de — postgres ayrı). Sade INT.
    op.add_column('equipments', sa.Column('owner_id', sa.Integer(), nullable=True))
    op.create_index('ix_equipments_owner_id', 'equipments', ['owner_id'])


def downgrade():
    op.drop_index('ix_equipments_owner_id', table_name='equipments')
    op.drop_column('equipments', 'owner_id')
    op.drop_column('pins', 'rated_power_kw')
    op.drop_column('pins', 'rotor_diameter')
    op.drop_column('pins', 'hub_height')
    op.drop_column('pins', 'panel_power_w')
    op.drop_column('pins', 'panel_azimuth')
    op.drop_column('pins', 'panel_tilt')
