"""climatology table + pins.installation_date (S1)

2026-05-17 Sprint S1 — Climatology Skoru + Pin Generation History.

İki ana değişiklik:

1) `climatology` tablosu (yeni, SystemBase):
   81 il × 3 tip × (opsiyonel ilçe) için 10+ yıl günlük + 2 yıl saatlik
   veriden tek seferlik hesaplanan iklim metrikleri. 6 ayda bir refresh.
   `province_analysis` tablosu deprecate edilir; mevcut endpoint'ler
   (`/analysis/provinces`, `/analysis/province/{name}`, choropleth)
   climatology'den okumaya geçer. Eski tablo silinmez (geriye uyum +
   karşılaştırma için tutulur, bir sonraki sprintte silinebilir).

2) `pins.installation_date` (yeni alan, UserBase):
   Pin'in santralin gerçekte ne zaman kurulduğunu tutar. Default
   `created_at` ile aynı (yeni pinler için). Kullanıcı isterse geçmişe
   tarihli pin ekleyip "kurulduğundan beri üretim" hesabını alır.

Bkz: BACKEND-PLAN-2026-05-17.md (S1 detay), Manisa örneği (climatology
modeli karar gerekçesi).

Revision ID: 015_climatology_pin_install
Revises: 014_fix_equipments_seq
Create Date: 2026-05-17
"""

from alembic import op
import sqlalchemy as sa


revision = '015_climatology_pin_install'
down_revision = '014_fix_equipments_seq'
branch_labels = None
depends_on = None


def upgrade():
    # ── climatology tablosu ─────────────────────────────────────────────
    op.create_table(
        'climatology',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('province_name', sa.String(), nullable=False, index=True),
        # district_name nullable: NULL = il bazlı toplam, dolu = belirli ilçe
        sa.Column('district_name', sa.String(), nullable=True, index=True),
        sa.Column('resource_type', sa.String(), nullable=False, index=True),  # wind|solar|hydro

        # ── Rüzgar metrikleri (10+ yıl + 2 yıl saatlik bileşik) ──
        sa.Column('avg_wind_speed_10y', sa.Float(), nullable=True),  # m/s @ 100m
        sa.Column('weibull_k', sa.Float(), nullable=True),           # şekil (süreklilik)
        sa.Column('weibull_c', sa.Float(), nullable=True),           # skala

        # ── Güneş metrikleri ──
        sa.Column('avg_solar_irradiance_10y', sa.Float(), nullable=True),  # kWh/m²/yıl (toplam)
        sa.Column('avg_ghi_wm2', sa.Float(), nullable=True),               # W/m² ortalama

        # ── Termal / genel ──
        sa.Column('avg_temperature_10y', sa.Float(), nullable=True),  # °C
        sa.Column('seasonal_variance', sa.Float(), nullable=True),     # 0-1 normalize

        # ── Teknik üretkenlik ──
        sa.Column('capacity_factor', sa.Float(), nullable=True),  # 0-1, kaynak tipine göre formül

        # ── Saatlik tipik profil (12 ay × 24 saat) ──
        # JSON: {"month_1_hour_0": value, ...} veya {"1": {"0": v, ...}}
        # Pin generation interpolasyonunda kullanılır (eski tarihli pinler için)
        sa.Column('hourly_typical_profile', sa.JSON(), nullable=True),

        # ── Multi-criteria skor (statik, climatology bazlı) ──
        sa.Column('score_climatology', sa.Float(), nullable=True),  # 0-100

        # ── Meta ──
        sa.Column('sample_count_daily', sa.Integer(), nullable=True),
        sa.Column('sample_count_hourly', sa.Integer(), nullable=True),
        sa.Column('data_start_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('data_end_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('computed_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now(), onupdate=sa.func.now()),

        # Unique: il + ilçe (nullable) + kaynak — aynı kombinasyon tek satır
        sa.UniqueConstraint(
            'province_name', 'district_name', 'resource_type',
            name='uq_climatology_loc_resource',
        ),
    )
    # Sıralama için sık kullanılan index: tip + skor
    op.create_index(
        'ix_climatology_type_score',
        'climatology',
        ['resource_type', 'score_climatology'],
    )

    # ── pins.installation_date ──────────────────────────────────────────
    op.add_column(
        'pins',
        sa.Column('installation_date', sa.DateTime(timezone=True), nullable=True),
    )
    # Mevcut pinler için installation_date = created_at (geriye uyum)
    op.execute(
        "UPDATE pins SET installation_date = created_at "
        "WHERE installation_date IS NULL"
    )


def downgrade():
    op.drop_column('pins', 'installation_date')
    op.drop_index('ix_climatology_type_score', table_name='climatology')
    op.drop_table('climatology')
