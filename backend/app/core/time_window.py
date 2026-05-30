"""
Paylaşılan zaman penceresi çözümleyicisi.

Tematik harita katmanları (choropleth, animasyon, summary) kullanıcının
seçtiği moda göre farklı zaman pencerelerinde veri gösterir. Tek vokabüler:

- ``current``     → son 1 saat (anlık snapshot, point-in-time)
- ``week``        → son 7 gün (varsayılan; eski hours=168 davranışıyla aynı)
- ``month``       → son 30 gün
- ``threeMonth``  → son 90 gün  (Önerilen Bölgeler 1-6 ay penceresi için)
- ``sixMonth``    → son 180 gün
- ``yearly``      → son 365 gün (iklimsel)
- ``season``      → son 365 gün + mevsim ay filtresi (DJF/MAM/JJA/SON)

SQL tarafında WHERE timestamp BETWEEN start AND end + opsiyonel
EXTRACT(MONTH) IN (...) filtresi uygulanır. Endpoint'ler bu helper'ı
çağırıp dönen TimeWindow'u direkt query'e bağlar.

``custom`` modu burada yok — manuel start/end alan endpoint'ler (örn.
animasyon /weather/animation) tarihleri kendi parse eder.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException

# Meteorolojik mevsim tanımı (WMO): Kış=DJF, İlkbahar=MAM, Yaz=JJA, Sonbahar=SON
SEASON_MONTHS: dict[str, list[int]] = {
    "winter": [12, 1, 2],
    "spring": [3, 4, 5],
    "summer": [6, 7, 8],
    "autumn": [9, 10, 11],
}

# Mod → gün sayısı (yearly tabanlı season hariç). current ayrı dallanır.
# 2026-05-28: twoYear/fiveYear/tenYear uzun pencereler eklendi (precompute).
MODE_DAYS: dict[str, int] = {
    "week": 7,
    "month": 30,
    "threeMonth": 90,
    "sixMonth": 180,
    "yearly": 365,
    "twoYear": 730,
    "fiveYear": 1825,
    "tenYear": 3650,
}

VALID_MODES = {
    "current", "week", "month", "threeMonth", "sixMonth", "yearly", "season",
    "twoYear", "fiveYear", "tenYear",
}

# Ayda bir precompute edilen ("ağır") modlar — her istekte hesaplanmaz,
# thematic_aggregate tablosundan okunur. build_thematic_aggregates.py doldurur.
# Kısa modlar (current/week/month/threeMonth) on-demand kalır (sık değişir, ucuz).
PRECOMPUTED_MODES = {
    "sixMonth", "yearly", "season", "twoYear", "fiveYear", "tenYear",
}

# Endpoint Query regex'lerinde kullanmak için ortak pattern.
MODE_REGEX = (
    "^(current|week|month|threeMonth|sixMonth|yearly|season"
    "|twoYear|fiveYear|tenYear)$"
)
SEASON_REGEX = "^(winter|spring|summer|autumn)$"


@dataclass(frozen=True)
class TimeWindow:
    """Çözümlenmiş zaman penceresi.

    - ``start`` / ``end``: inclusive timestamp aralığı (UTC)
    - ``months``: boş değilse sadece bu aylardaki satırlar dahil edilir
    - ``mode`` / ``season``: telemetri/log için orijinal input
    - ``is_point_in_time``: True ise "en son 1 saat" — agregasyon değil snapshot
    - ``days``: pencere uzunluğu gün cinsinden (current için 0)
    """

    start: datetime
    end: datetime
    months: Optional[list[int]]
    mode: str
    season: Optional[str]
    is_point_in_time: bool
    days: int


def resolve_time_window(
    mode: Optional[str],
    season: Optional[str],
    *,
    now: Optional[datetime] = None,
) -> TimeWindow:
    """
    mode/season query parametrelerini TimeWindow'a çevirir.

    - ``mode`` None veya "current" → son 1 saat
    - ``mode in {week, month, threeMonth, sixMonth, yearly}`` → ilgili gün penceresi
    - ``mode == "season"`` → son 365 gün + mevsim ay filtresi
                              (season parametresi zorunlu)

    Geçersiz input 400 fırlatır — caller'lar ek doğrulama yapmasın.
    """
    now = now or datetime.utcnow()
    resolved_mode = (mode or "current")

    if resolved_mode not in VALID_MODES:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Geçersiz mode='{mode}'. "
                f"İzinli değerler: {sorted(VALID_MODES)}"
            ),
        )

    # current: son 1 saat (point-in-time snapshot)
    if resolved_mode == "current":
        return TimeWindow(
            start=now - timedelta(hours=1),
            end=now,
            months=None,
            mode="current",
            season=None,
            is_point_in_time=True,
            days=0,
        )

    # week / month / threeMonth / sixMonth / yearly
    if resolved_mode in MODE_DAYS:
        days = MODE_DAYS[resolved_mode]
        return TimeWindow(
            start=now - timedelta(days=days),
            end=now,
            months=None,
            mode=resolved_mode,
            season=None,
            is_point_in_time=False,
            days=days,
        )

    # season — yearly tabanı + ay filtresi
    if not season:
        raise HTTPException(
            status_code=400,
            detail="mode='season' için season parametresi zorunludur "
                   "(winter|spring|summer|autumn).",
        )
    season_key = season.lower()
    months = SEASON_MONTHS.get(season_key)
    if months is None:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Geçersiz season='{season}'. "
                f"İzinli değerler: {sorted(SEASON_MONTHS.keys())}"
            ),
        )
    return TimeWindow(
        start=now - timedelta(days=365),
        end=now,
        months=months,
        mode="season",
        season=season_key,
        is_point_in_time=False,
        days=365,
    )
