"""
SRRP — Finansal Hesap Varsayımları (Aşama 3.A)
==============================================

Sektör kabul varsayımları — her senaryonun finansal projeksiyonu bu
değerleri tabanı olarak kullanır. ``FinanceAssumptions`` tablosu (DB)
varsa onun değerleri kullanıcı override eder.

Referanslar:
- IRENA Renewable Power Generation Costs in 2024 (Mayıs 2025 raporu)
- EPDK 2025 Türkiye elektrik tarifeleri
- TEDAŞ ortalama şebeke fiyatları
- Türkiye Enerji ve Tabii Kaynaklar Bakanlığı, 2024 enerji bilançosu
- Şebeke karbon yoğunluğu: 480 g CO₂/kWh (TR 2024 ortalaması)

Tüm para birimleri **USD**'dir (FX volatilitesinden bağımsız tutmak için).
Frontend'de gösterilirken `USD_TO_TRY` ile çevrilir.
"""
from __future__ import annotations

# ─── CAPEX (Capital Expenditure) ─────────────────────────────────────────────
# Her MW kurulu güç için yatırım maliyeti (USD/MW).
# Düşüş trendi: Solar son 10 yılda %85 ucuzladı.
DEFAULT_CAPEX_PER_MW: dict[str, float] = {
    "Güneş Paneli":  600_000,    # 0.6M USD/MW (utility-scale PV)
    "Rüzgar Türbini": 1_200_000,  # 1.2M USD/MW (onshore)
    "Hidroelektrik":  2_500_000,  # 2.5M USD/MW (orta ölçek HES)
}

# ─── OPEX (Operating Expenditure) ────────────────────────────────────────────
# Yıllık işletme gideri = CAPEX'in oranı (bakım + sigorta + personel).
DEFAULT_OPEX_PCT_YEARLY: dict[str, float] = {
    "Güneş Paneli":  0.015,  # %1.5/yıl
    "Rüzgar Türbini": 0.025,  # %2.5/yıl
    "Hidroelektrik":  0.020,  # %2.0/yıl
}

# ─── Proje Ömrü (yıl) ────────────────────────────────────────────────────────
# Ekipman beklenen ekonomik ömrü; finansal projeksiyon bu süreyi kapsar.
DEFAULT_LIFETIME_YEARS: dict[str, int] = {
    "Güneş Paneli":  25,
    "Rüzgar Türbini": 20,
    "Hidroelektrik":  50,
}

# ─── Capacity Factor Fallback ────────────────────────────────────────────────
# Pin'in `capacity_factor` alanı yoksa kullanılır (saha-bağımsız tipik
# ortalama). Türkiye iklim koşulları için kabul.
DEFAULT_CAPACITY_FACTOR_FALLBACK: dict[str, float] = {
    "Güneş Paneli":  0.18,  # %18 — TR ortalama PV
    "Rüzgar Türbini": 0.32,  # %32 — onshore TR
    "Hidroelektrik":  0.45,  # %45 — büyük HES
}

# ─── Elektrik Fiyatı (toptan / spot) ─────────────────────────────────────────
# YEKDEM ortalaması + ticaret marjı; sektör ortalamasının üst bandı.
DEFAULT_ELECTRICITY_PRICE_USD_PER_KWH: float = 0.085  # ~2.8 TL @ 33 TL/USD

# ─── İskonto Oranı (NPV/LCOE) ────────────────────────────────────────────────
# Türkiye finansman piyasası — risksiz faiz + risk primi (USD bazlı).
DEFAULT_DISCOUNT_RATE: float = 0.08

# ─── CO₂ Şebeke Yoğunluğu ────────────────────────────────────────────────────
# Türkiye şebeke karbon yoğunluğu (480 g CO₂/kWh, 2024 fosil ağırlıklı).
# Yeşil enerji üretimi şebekede yerine geçtiğinde bu kadar emisyon önler.
DEFAULT_CO2_INTENSITY_G_PER_KWH: float = 480.0

# ─── FX (USD ↔ TRY) ──────────────────────────────────────────────────────────
# Frontend'de TL gösterim için kullanılır. Settings'ten override edilebilir.
USD_TO_TRY: float = 33.0
