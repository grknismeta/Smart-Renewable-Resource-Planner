"""
SRRP — Climatology Compute Service (Sprint S1, 2026-05-17)
==========================================================

10+ yıl günlük (`weather_data`) + 2 yıl saatlik (`hourly_weather_data`)
verisinden iklim metrikleri hesaplayıp `climatology` tablosuna yazar.

**Mimari karar — Manisa örneği:**
Skor sürekli recompute edilmez. 10+ yıllık ortalama bölgenin karakterini
verir — son ay az rüzgar diye Manisa "düşük puan" almaz. 6 ayda bir
refresh yeterli; uzun vade iklim ortalaması zaten yavaş değişir.

**Hesaplanan metrikler (her il+ilçe+kaynak için):**
- `avg_wind_speed_10y` (m/s @ 100m) — uzun vade ortalama
- `weibull_k`, `weibull_c` — şekil + skala parametreleri (RES süreklilik)
- `avg_solar_irradiance_10y` (kWh/m²/yıl) — yıllık toplam
- `avg_ghi_wm2` (W/m² ortalama) — saatlik ortalama
- `avg_temperature_10y` (°C)
- `seasonal_variance` (0-1 normalize)
- `capacity_factor` (0-1) — kaynak tipine göre formül
- `hourly_typical_profile` (JSON: 12 ay × 24 saat) — interpolasyon için
- `score_climatology` (0-100) — multi-criteria

**Kullanım:**
    from app.services.climatology_service import (
        compute_for_province,           # tek il (pilot)
        compute_for_all_provinces,      # 81 il yay
        get_climatology,                # cache okuma
    )

    # Pilot — tek il
    result = compute_for_province("Manisa", "wind")
    print(result)

    # Tüm Türkiye (uzun sürer, background job)
    compute_for_all_provinces(resource_types=("wind", "solar"))

Plan: BACKEND-PLAN-2026-05-17.md S1
"""
from __future__ import annotations

import json
import logging
import math
import statistics
from dataclasses import dataclass
from datetime import datetime
from typing import Iterable, Optional

from sqlalchemy import func, extract, and_, or_

from app.db.database import SystemSessionLocal
from app.db.models import (
    Climatology,
    HourlyWeatherData,
    WeatherData,
)


# ─── Türkçe ASCII normalize (DB'de "Balikesir", input "Balıkesir") ──────────
# Vault: PinAddFlow + SelectionModes ASCII fold pattern. Türkiye'ye özel
# çevrim (Python `.lower()` "İ"yi "i̇" gibi combining yapar — yanlış).

_TR_FOLD_TABLE = str.maketrans({
    "İ": "I", "I": "I", "ı": "i", "i": "i",
    "Ğ": "G", "ğ": "g",
    "Ş": "S", "ş": "s",
    "Ç": "C", "ç": "c",
    "Ö": "O", "ö": "o",
    "Ü": "U", "ü": "u",
})


def _tr_ascii_fold(s: str) -> str:
    """'Balıkesir' → 'Balikesir', 'Çanakkale' → 'Canakkale'. DB'deki kayıtlar
    bazı kaynakta normalize edilmiş (ı→i, ç→c) bazısı orijinal Türkçe.
    Filtrelerde her iki varyasyonu OR ile dene."""
    return (s or "").translate(_TR_FOLD_TABLE)

logger = logging.getLogger(__name__)

VALID_RESOURCES = ("wind", "solar", "hydro")
DEFAULT_RESOURCES = ("wind", "solar")  # hydro Sprint S3'te (HES PostGIS sonrası)

# Türbin power curve referans değerleri (capacity factor için)
# Tipik Vestas V112-3.45MW class — sade trapezoidal approximation
WIND_CUTIN_MS = 3.0
WIND_RATED_MS = 12.0
WIND_CUTOUT_MS = 25.0

# Güneş paneli referans (1 kW peak → STC: 1000 W/m² × 1 m² × 1.0 verim)
# Capacity factor: gerçek üretim / nominal × 8760 saat
GHI_STC_WM2 = 1000.0


# ─── Dataclasses ────────────────────────────────────────────────────────────

@dataclass
class ClimatologyResult:
    province_name: str
    district_name: Optional[str]
    resource_type: str

    avg_wind_speed_10y: Optional[float] = None
    weibull_k: Optional[float] = None
    weibull_c: Optional[float] = None
    avg_solar_irradiance_10y: Optional[float] = None
    avg_ghi_wm2: Optional[float] = None
    avg_temperature_10y: Optional[float] = None
    seasonal_variance: Optional[float] = None
    capacity_factor: Optional[float] = None
    hourly_typical_profile: Optional[dict] = None
    score_climatology: Optional[float] = None

    sample_count_daily: int = 0
    sample_count_hourly: int = 0
    data_start_date: Optional[datetime] = None
    data_end_date: Optional[datetime] = None

    def to_dict(self) -> dict:
        return {
            "province_name": self.province_name,
            "district_name": self.district_name,
            "resource_type": self.resource_type,
            "avg_wind_speed_10y": self.avg_wind_speed_10y,
            "weibull_k": self.weibull_k,
            "weibull_c": self.weibull_c,
            "avg_solar_irradiance_10y": self.avg_solar_irradiance_10y,
            "avg_ghi_wm2": self.avg_ghi_wm2,
            "avg_temperature_10y": self.avg_temperature_10y,
            "seasonal_variance": self.seasonal_variance,
            "capacity_factor": self.capacity_factor,
            "score_climatology": self.score_climatology,
            "sample_count_daily": self.sample_count_daily,
            "sample_count_hourly": self.sample_count_hourly,
        }


# ─── Weibull dağılımı tahmini (method of moments) ──────────────────────────

def estimate_weibull(values: list[float]) -> tuple[Optional[float], Optional[float]]:
    """Method-of-moments Weibull k, c tahmini.

    Tam MLE değil ama büyük örneklemde yeterince doğru. RES süreklilik
    göstergesi olarak `k`:
      - k > 2.0 = çok tutarlı rüzgar (Manisa gibi)
      - k 1.5-2.0 = orta
      - k < 1.5 = düzensiz

    Formül (Justus 1978):
        k ≈ (σ / μ) ^ -1.086
        c ≈ μ / Γ(1 + 1/k)
    """
    if not values or len(values) < 100:
        return None, None
    try:
        mean = statistics.fmean(values)
        std = statistics.pstdev(values)
        if mean <= 0 or std <= 0:
            return None, None
        cv = std / mean
        k = cv ** -1.086
        # Gamma(1 + 1/k) — math.gamma kullanır
        c = mean / math.gamma(1 + 1.0 / k)
        return round(k, 3), round(c, 3)
    except Exception as e:
        logger.warning("[climatology] Weibull tahmin hatası: %s", e)
        return None, None


# ─── Capacity factor hesapları ─────────────────────────────────────────────

def _wind_power_curve(v: float) -> float:
    """Sade trapezoidal power curve (0-1 normalize)."""
    if v < WIND_CUTIN_MS or v > WIND_CUTOUT_MS:
        return 0.0
    if v >= WIND_RATED_MS:
        return 1.0
    # Cut-in → rated arası lineer (basit yaklaşım; gerçek curve cube law)
    # Daha doğru: cube law segment, ama bu pilot için yeterli
    return ((v - WIND_CUTIN_MS) / (WIND_RATED_MS - WIND_CUTIN_MS)) ** 3


def compute_wind_capacity_factor(values: list[float]) -> Optional[float]:
    """Saatlik rüzgar hızı (m/s) listesinden ortalama capacity factor."""
    if not values:
        return None
    return round(sum(_wind_power_curve(v) for v in values) / len(values), 4)


def compute_solar_capacity_factor(ghi_values: list[float]) -> Optional[float]:
    """Saatlik GHI (W/m²) listesinden capacity factor.

    PR (performance ratio) 0.80 alındı — modern panellerde gerçekçi.
    """
    if not ghi_values:
        return None
    pr = 0.80
    cf = sum(min(v, GHI_STC_WM2) for v in ghi_values) / (GHI_STC_WM2 * len(ghi_values)) * pr
    return round(cf, 4)


# ─── Seasonal variance ──────────────────────────────────────────────────────

def compute_seasonal_variance(monthly_means: dict[int, float]) -> Optional[float]:
    """12 aylık ortalamadan normalize varyans (0-1).

    0 = mevsim arası fark yok (kararlı), 1 = çok değişken.
    """
    if not monthly_means or len(monthly_means) < 6:
        return None
    vals = list(monthly_means.values())
    mean = statistics.fmean(vals)
    if mean <= 0:
        return None
    std = statistics.pstdev(vals)
    cv = std / mean  # coefficient of variation
    # CV ~0 mükemmel, ~1+ kötü → tanh ile 0-1'e clip
    return round(min(1.0, math.tanh(cv * 1.5)), 4)


# ─── Hourly typical profile (12 ay × 24 saat) ───────────────────────────────

def build_hourly_profile(
    hourly_rows: list[tuple[int, int, float]],
) -> dict[str, dict[str, float]]:
    """Saatlik veri tuple'ları (month, hour, value) → 12×24 ortalama matrisi.

    Pin generation interpolasyonu için kullanılır: eski tarihli pin
    günlük veriye sahip ama saatlik profil bu tablodan gelir.

    Çıktı: {"1": {"0": 0.5, "1": 0.4, ...}, "2": {...}, ...}
    """
    if not hourly_rows:
        return {}
    # Toplama
    buckets: dict[tuple[int, int], list[float]] = {}
    for month, hour, value in hourly_rows:
        if value is None:
            continue
        buckets.setdefault((month, hour), []).append(float(value))
    # Ortalama
    profile: dict[str, dict[str, float]] = {}
    for (month, hour), vals in buckets.items():
        if not vals:
            continue
        profile.setdefault(str(month), {})[str(hour)] = round(
            statistics.fmean(vals), 3
        )
    return profile


# ─── Climatology score (multi-criteria) ────────────────────────────────────

def compute_score(result: ClimatologyResult) -> Optional[float]:
    """0-100 multi-criteria skor. Kaynak tipine göre formül.

    Plan'da S1 detayında:
        score_wind = (CF×0.40 + abs_wind×0.25 + k×0.25 + stability×0.10) × 100
        score_solar = (CF×0.40 + ghi_norm×0.30 + (1-cloud_var)×0.20 + temp_derate×0.10) × 100

    Not: grid_proximity ve slope_orientation S3'te (PostGIS sonrası) eklenir.
    Pilot fazda mevcut metrikler.
    """
    t = result.resource_type
    cf = result.capacity_factor or 0
    season_stab = 1 - (result.seasonal_variance or 0)

    if t == "wind":
        wind_speed = result.avg_wind_speed_10y or 0
        # 2026-05-17 kalibrasyon: Türkiye dağılımı (3-9 m/s) — 3 m/s cut-in
        # altı 0, 9 m/s+ ideal. Eski (4-8) çok dar geliyordu.
        abs_score = max(0, min(1, (wind_speed - 3.0) / 6.0))
        # k ideal 2-3 arası (modern türbinlerde 2.0+ "sürekli rüzgar")
        k = result.weibull_k or 0
        k_score = max(0, min(1, k / 2.5))
        # CF en güçlü gösterge — ağırlık artırıldı (0.40 → 0.50)
        raw = (cf * 0.50) + (abs_score * 0.20) + (k_score * 0.20) + (season_stab * 0.10)
        return round(raw * 100, 2)

    if t == "solar":
        ghi = result.avg_ghi_wm2 or 0
        # GHI 100-300 W/m² Türkiye aralığı, 200 ortalama
        ghi_score = max(0, min(1, (ghi - 100) / 200))
        # Sıcaklık derate: 25°C üstü kayıp
        temp = result.avg_temperature_10y or 15
        temp_derate = max(0, min(1, 1 - max(0, temp - 25) / 30))
        raw = (cf * 0.40) + (ghi_score * 0.30) + (season_stab * 0.20) + (temp_derate * 0.10)
        return round(raw * 100, 2)

    if t == "hydro":
        # S3'te PostGIS akarsu mesafe + debi gelince. Şimdilik None.
        return None

    return None


# ─── Ana hesap fonksiyonu ──────────────────────────────────────────────────

def compute_for_province(
    province_name: str,
    resource_type: str,
    district_name: Optional[str] = None,
) -> ClimatologyResult:
    """Tek il (veya il+ilçe) × tek kaynak için iklim metrikleri.

    Hesap kaynakları:
    - Saatlik veriden (`hourly_weather_data`, son 2 yıl): capacity_factor,
      Weibull k/c, hourly_typical_profile
    - Günlük veriden (`weather_data`, 10+ yıl): uzun vade ortalamalar,
      seasonal_variance

    Yetersiz veri (< 100 saatlik kayıt) durumunda kısmi sonuç döner.
    """
    if resource_type not in VALID_RESOURCES:
        raise ValueError(f"resource_type {VALID_RESOURCES} olmalı")

    # 2026-05-24: province_name'i Türkçe canonical'a normalize et.
    # Climatology'de aynı il "Balıkesir" + "Balikesir" gibi dublike satırlara
    # yazılmasını önler. DB sorguları zaten province_aliases ile her iki
    # varyasyonu match ediyor; insert path canonical'a normalize.
    from app.services.province_aliases import to_canonical
    province_name = to_canonical(province_name)

    result = ClimatologyResult(
        province_name=province_name,
        district_name=district_name,
        resource_type=resource_type,
    )

    # Türkçe ASCII fold — DB bazı kayıtları "Balikesir" (ı→i) tutuyor
    prov_orig = province_name
    prov_fold = _tr_ascii_fold(province_name)
    dist_orig = district_name
    dist_fold = _tr_ascii_fold(district_name) if district_name else None

    with SystemSessionLocal() as db:
        # ── 1) Saatlik veri sorgusu ────────────────────────────────────
        # 2026-05-17 — İl bazlı climatology için TÜM ilçelerin verisini
        # dahil et (eski "district=NULL OR 'Merkez'" filter Balıkesir/
        # Manisa gibi reform sonrası "Karesi"/"Yunusemre" olan illerde
        # yetersiz kayıt döndürüyordu). İl seviyesi = il geneli ortalama.
        h_filter = [
            or_(
                HourlyWeatherData.city_name == prov_orig,
                HourlyWeatherData.city_name == prov_fold,
            )
        ]
        if district_name:
            # İlçe bazlı climatology: exact district + ASCII fold varyasyonu
            h_filter.append(
                or_(
                    HourlyWeatherData.district_name == dist_orig,
                    HourlyWeatherData.district_name == dist_fold,
                )
            )
        # else: İl bazlı — district filter YOK, tüm ilçeler ortalanır

        # Sayım
        hourly_count = db.query(func.count(HourlyWeatherData.id)).filter(
            and_(*h_filter)
        ).scalar() or 0
        result.sample_count_hourly = hourly_count

        # Veri yoksa erken çık
        if hourly_count < 100:
            logger.info(
                "[climatology] %s/%s/%s: az veri (%d saatlik), skip",
                province_name, district_name or "-", resource_type, hourly_count,
            )
            return result

        # Veri aralığı
        date_range = db.query(
            func.min(HourlyWeatherData.timestamp),
            func.max(HourlyWeatherData.timestamp),
        ).filter(and_(*h_filter)).first()
        if date_range:
            result.data_start_date = date_range[0]
            result.data_end_date = date_range[1]

        # Genel sıcaklık ortalaması (her kaynak için ortak)
        avg_temp = db.query(func.avg(HourlyWeatherData.temperature_2m)).filter(
            and_(*h_filter, HourlyWeatherData.temperature_2m.isnot(None))
        ).scalar()
        if avg_temp is not None:
            result.avg_temperature_10y = round(float(avg_temp), 2)

        # ── 2) Kaynak-spesifik metrikler ───────────────────────────────
        if resource_type == "wind":
            # Tüm saatlik rüzgar hızları (büyük sorgu — chunk yapabilir)
            wind_rows = db.query(HourlyWeatherData.wind_speed_100m).filter(
                and_(*h_filter, HourlyWeatherData.wind_speed_100m.isnot(None))
            ).all()
            wind_values = [r[0] for r in wind_rows if r[0] is not None]
            if wind_values:
                result.avg_wind_speed_10y = round(statistics.fmean(wind_values), 3)
                result.weibull_k, result.weibull_c = estimate_weibull(wind_values)
                result.capacity_factor = compute_wind_capacity_factor(wind_values)

            # 12 ay × 24 saat tipik profil
            hourly_grouped = db.query(
                extract("month", HourlyWeatherData.timestamp).label("month"),
                extract("hour", HourlyWeatherData.timestamp).label("hour"),
                func.avg(HourlyWeatherData.wind_speed_100m).label("avg_val"),
            ).filter(
                and_(*h_filter, HourlyWeatherData.wind_speed_100m.isnot(None))
            ).group_by("month", "hour").all()
            result.hourly_typical_profile = build_hourly_profile([
                (int(r.month), int(r.hour), float(r.avg_val))
                for r in hourly_grouped if r.avg_val is not None
            ])

            # Mevsim varyansı — aylık ortalama
            monthly = db.query(
                extract("month", HourlyWeatherData.timestamp).label("month"),
                func.avg(HourlyWeatherData.wind_speed_100m).label("avg_val"),
            ).filter(
                and_(*h_filter, HourlyWeatherData.wind_speed_100m.isnot(None))
            ).group_by("month").all()
            monthly_means = {
                int(r.month): float(r.avg_val) for r in monthly if r.avg_val is not None
            }
            result.seasonal_variance = compute_seasonal_variance(monthly_means)

        elif resource_type == "solar":
            ghi_rows = db.query(HourlyWeatherData.shortwave_radiation).filter(
                and_(*h_filter, HourlyWeatherData.shortwave_radiation.isnot(None))
            ).all()
            ghi_values = [r[0] for r in ghi_rows if r[0] is not None]
            if ghi_values:
                result.avg_ghi_wm2 = round(statistics.fmean(ghi_values), 2)
                # Yıllık toplam (kWh/m²) — sample sayısından extrapolate
                # Ortalama W/m² × 8760 / 1000 = kWh/m²/yıl (her saat 1m² varsayım)
                # Gerçek değer için sample_count_hourly / 24 = gün sayısı
                days = result.sample_count_hourly / 24 if result.sample_count_hourly else 365
                total_wh = sum(ghi_values)
                result.avg_solar_irradiance_10y = round(
                    (total_wh / days) * 365 / 1000, 1
                )
                result.capacity_factor = compute_solar_capacity_factor(ghi_values)

            # 12×24 GHI tipik profili
            hourly_grouped = db.query(
                extract("month", HourlyWeatherData.timestamp).label("month"),
                extract("hour", HourlyWeatherData.timestamp).label("hour"),
                func.avg(HourlyWeatherData.shortwave_radiation).label("avg_val"),
            ).filter(
                and_(*h_filter, HourlyWeatherData.shortwave_radiation.isnot(None))
            ).group_by("month", "hour").all()
            result.hourly_typical_profile = build_hourly_profile([
                (int(r.month), int(r.hour), float(r.avg_val))
                for r in hourly_grouped if r.avg_val is not None
            ])

            # Aylık ortalama GHI
            monthly = db.query(
                extract("month", HourlyWeatherData.timestamp).label("month"),
                func.avg(HourlyWeatherData.shortwave_radiation).label("avg_val"),
            ).filter(
                and_(*h_filter, HourlyWeatherData.shortwave_radiation.isnot(None))
            ).group_by("month").all()
            monthly_means = {
                int(r.month): float(r.avg_val) for r in monthly if r.avg_val is not None
            }
            result.seasonal_variance = compute_seasonal_variance(monthly_means)

        # ── 3) 10+ yıllık günlük veri ile uzun vade ortalama (varsa) ──
        d_filter = [
            or_(
                WeatherData.province_name == prov_orig,
                WeatherData.province_name == prov_fold,
            )
        ]
        if district_name:
            d_filter.append(
                or_(
                    WeatherData.district_name == dist_orig,
                    WeatherData.district_name == dist_fold,
                )
            )
        daily_count = db.query(func.count(WeatherData.id)).filter(
            and_(*d_filter)
        ).scalar() or 0
        result.sample_count_daily = daily_count

        if daily_count > 365:
            if resource_type == "wind" and result.avg_wind_speed_10y is None:
                # Saatlikten gelemedi → günlükten
                avg_w = db.query(func.avg(WeatherData.wind_speed_mean)).filter(
                    and_(*d_filter)
                ).scalar()
                if avg_w:
                    result.avg_wind_speed_10y = round(float(avg_w), 3)
            elif resource_type == "solar" and result.avg_solar_irradiance_10y is None:
                # Günlük shortwave_radiation_sum = MJ/m²/gün → yıllık kWh
                avg_d = db.query(func.avg(WeatherData.shortwave_radiation_sum)).filter(
                    and_(*d_filter)
                ).scalar()
                if avg_d:
                    # MJ/m²/gün × 365 / 3.6 = kWh/m²/yıl
                    result.avg_solar_irradiance_10y = round(float(avg_d) * 365 / 3.6, 1)

        # ── 4) Skor hesabı ─────────────────────────────────────────────
        result.score_climatology = compute_score(result)

    return result


# ─── DB yazma ───────────────────────────────────────────────────────────────

def upsert_climatology(result: ClimatologyResult) -> int:
    """ClimatologyResult'i `climatology` tablosuna yaz (upsert)."""
    with SystemSessionLocal() as db:
        existing = db.query(Climatology).filter(
            Climatology.province_name == result.province_name,
            Climatology.district_name == result.district_name,
            Climatology.resource_type == result.resource_type,
        ).first()

        if existing:
            row = existing
        else:
            row = Climatology(
                province_name=result.province_name,
                district_name=result.district_name,
                resource_type=result.resource_type,
            )
            db.add(row)

        # Tüm metrikleri ata
        row.avg_wind_speed_10y = result.avg_wind_speed_10y
        row.weibull_k = result.weibull_k
        row.weibull_c = result.weibull_c
        row.avg_solar_irradiance_10y = result.avg_solar_irradiance_10y
        row.avg_ghi_wm2 = result.avg_ghi_wm2
        row.avg_temperature_10y = result.avg_temperature_10y
        row.seasonal_variance = result.seasonal_variance
        row.capacity_factor = result.capacity_factor
        row.hourly_typical_profile = result.hourly_typical_profile
        row.score_climatology = result.score_climatology
        row.sample_count_daily = result.sample_count_daily
        row.sample_count_hourly = result.sample_count_hourly
        row.data_start_date = result.data_start_date
        row.data_end_date = result.data_end_date

        db.commit()
        db.refresh(row)
        return int(row.id)


# ─── Batch hesap ────────────────────────────────────────────────────────────

def compute_for_all_provinces(
    resource_types: Iterable[str] = DEFAULT_RESOURCES,
    province_names: Optional[Iterable[str]] = None,
    save: bool = True,
) -> list[ClimatologyResult]:
    """81 il × resource_types için hesap yap, climatology tablosuna yaz.

    Args:
        resource_types: hangi kaynaklar (default: wind + solar; hydro S3'te)
        province_names: belirli iller (None → DB'den distinct çek)
        save: True = upsert; False = sadece compute, dön

    Returns: ClimatologyResult listesi (debug için).
    """
    if province_names is None:
        with SystemSessionLocal() as db:
            rows = db.query(HourlyWeatherData.city_name).distinct().all()
            province_names = sorted({r[0] for r in rows if r[0]})

    results: list[ClimatologyResult] = []
    total = len(list(province_names)) * len(list(resource_types))
    i = 0
    for province in province_names:
        for resource in resource_types:
            i += 1
            try:
                r = compute_for_province(province, resource)
                if save:
                    upsert_climatology(r)
                results.append(r)
                logger.info(
                    "[%d/%d] %s/%s → score=%s cf=%s samples=%d",
                    i, total, province, resource,
                    r.score_climatology, r.capacity_factor, r.sample_count_hourly,
                )
            except Exception as e:
                logger.exception("[climatology] %s/%s hata: %s", province, resource, e)

    # 2026-05-25 (H5): Kaynak-içi normalize — her resource için min-max
    # 0-100. Türkiye ortalamasının her zaman ~50+ olduğu durumda (rüzgar
    # için), kullanıcı kıyaslama yapamıyordu. Şimdi her kaynak için en iyi
    # il=100, en kötü=0 (adil sıralama).
    if save:
        normalize_scores_within_resource()

    return results


def normalize_scores_within_resource() -> None:
    """Climatology tablosundaki `score_climatology` değerlerini her kaynak
    için min-max 0-100 normalize eder. compute_for_all_provinces sonunda
    otomatik çağrılır; bağımsız olarak `scripts/normalize_climatology_scores.py`
    ile de çalıştırılabilir (mevcut veriyi düzeltmek için).
    """
    with SystemSessionLocal() as db:
        rows = (
            db.query(Climatology)
            .filter(
                Climatology.district_name.is_(None),
                Climatology.score_climatology.isnot(None),
            )
            .all()
        )
        by_resource: dict[str, list[Climatology]] = {}
        for r in rows:
            by_resource.setdefault(r.resource_type, []).append(r)  # type: ignore

        for resource, items in by_resource.items():
            scores = [float(r.score_climatology) for r in items]  # type: ignore
            if not scores:
                continue
            min_s = min(scores)
            max_s = max(scores)
            span = max_s - min_s
            if span < 0.01:
                logger.warning(
                    "[normalize] %s span<0.01 — atlanıyor", resource
                )
                continue
            for r in items:
                old = float(r.score_climatology)  # type: ignore
                r.score_climatology = round(  # type: ignore
                    (old - min_s) / span * 100, 2
                )
            logger.info(
                "[normalize] %s: %d il, [%.2f, %.2f] → [0, 100]",
                resource, len(items), min_s, max_s,
            )
        db.commit()


# ─── Cache okuma ────────────────────────────────────────────────────────────

def get_climatology(
    province_name: str,
    resource_type: str,
    district_name: Optional[str] = None,
) -> Optional[Climatology]:
    """Climatology tablosundan tek kayıt çek."""
    with SystemSessionLocal() as db:
        return db.query(Climatology).filter(
            Climatology.province_name.ilike(f"%{province_name}%"),
            Climatology.district_name == district_name,
            Climatology.resource_type == resource_type,
        ).first()


def get_top_climatology(
    resource_type: str,
    limit: int = 10,
    district_only: bool = False,
) -> list[Climatology]:
    """Top-N (skor sırasıyla) — Önerilen Bölgeler için."""
    with SystemSessionLocal() as db:
        q = db.query(Climatology).filter(
            Climatology.resource_type == resource_type,
            Climatology.score_climatology.isnot(None),
        )
        if district_only:
            q = q.filter(Climatology.district_name.isnot(None))
        else:
            q = q.filter(Climatology.district_name.is_(None))
        return q.order_by(Climatology.score_climatology.desc()).limit(limit).all()
