"""İklim aylık serileri — climatology JSON kolonlarından okur, NULL ise mock'tan.

2026-05-20 Sprint R1 — Reports v3 için Hava/Bölge tab'ları.

**Davranış:**
1. Önce `climatology` tablosundaki yeni JSON kolonları okumaya çalışır
   (Migration 016 — wind_direction_histogram, monthly_precipitation,
   monthly_cloud_cover, monthly_sunshine_hours, monthly_river_discharge)
2. Hepsi NULL ise: `backend/data/mock_climate_regional.json`'dan bölge
   bazlı template'i döndürür (Marmara/Ege/.../Güneydoğu)
3. R0 CSV'leri import edildikten sonra (scripts/import_colab_csvs.py)
   DB doluyor → mock otomatik devre dışı kalır

**Frontend için tek imza** — DB'den mi mock'tan mı geldiği frontend'i
ilgilendirmez, response şeması her zaman aynı:

    {
      "irradiance":    [12 float],  # kWh/m²/gün ortalama
      "wind_speed":    [12 float],  # m/s @ 100m
      "precipitation": [12 float],  # mm/ay
      "temperature":   [12 float],  # °C ortalama
      "cloud_cover":   [12 float],  # %
      "sunshine_hours":[12 float],  # saat/ay
      "river_discharge": [12 {mean, min, max}],
      "wind_rose": {
        "dominant": "NW",
        "histogram": {"N": .., "NE": .., ..., "NW": ..}  # toplam 100
      },
      "source": "db" | "mock_region:karadeniz"  # debug için
    }
"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from app.db.models import Climatology
from app.services.province_aliases import province_aliases

_DATA_DIR = Path(__file__).resolve().parent.parent.parent / "data"

# 8 yön sırası — wind_rose histogram için
WIND_BINS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


@lru_cache(maxsize=1)
def _mock_data() -> dict:
    with open(_DATA_DIR / "mock_climate_regional.json", encoding="utf-8") as f:
        return json.load(f)


@lru_cache(maxsize=1)
def _province_to_region() -> Dict[str, str]:
    """İl → bölge id mapping (tr_regions.json'dan türetilir)."""
    with open(_DATA_DIR / "tr_regions.json", encoding="utf-8") as f:
        regions = json.load(f)["regions"]
    out: Dict[str, str] = {}
    for r in regions:
        for p in r["provinces"]:
            out[p] = r["id"]
            # Türkçe karakter varyasyonları da
            for v in province_aliases(p):
                out[v] = r["id"]
    return out


def _build_wind_rose_from_dominant(dominant: str) -> Dict:
    """Dominant yöne göre 8-bin ağırlıklı histogram."""
    mock = _mock_data()
    pattern = mock["wind_rose_pattern"].get(dominant, mock["wind_rose_pattern"]["NW"])
    return {
        "dominant": dominant,
        "histogram": {b: pattern[i] for i, b in enumerate(WIND_BINS)},
    }


def _mock_climate_for_province(province: str) -> dict:
    """Province → region template lookup."""
    region_id = _province_to_region().get(province, "icanadolu")
    template = _mock_data()["regional_templates"].get(region_id)
    if not template:
        template = _mock_data()["regional_templates"]["icanadolu"]
    return {
        "irradiance":     template["irradiance"],
        "wind_speed":     template["wind_speed"],
        "precipitation":  template["precipitation"],
        "temperature":    template["temperature"],
        "cloud_cover":    template["cloud_cover"],
        "sunshine_hours": template["sunshine_hours"],
        "river_discharge": [
            {"mean": q, "min": round(q * 0.6, 2), "max": round(q * 1.6, 2)}
            for q in template["river_discharge"]
        ],
        "wind_rose": _build_wind_rose_from_dominant(template["dominant_wind_dir"]),
        "source": f"mock_region:{region_id}",
    }


def _wind_rose_from_histogram(hist_json: Optional[dict]) -> Optional[Dict]:
    """DB'deki wind_direction_histogram JSON'dan dominant yönü ve yıllık özetini çıkar.

    DB formatı: {"0": {"N": freq, "NE": ..}, "1": {...}, ..., "12": {...}}
    Key "0" = yıllık ort. Frontend için tek bin dağılımı + dominant döner.
    """
    if not hist_json:
        return None
    # Önce yıllık (key "0") dene, yoksa aylık ortalamadan üret
    annual = hist_json.get("0")
    if not annual:
        # Aylık ortalamalardan yıllık türet
        annual = {b: 0.0 for b in WIND_BINS}
        count = 0
        for m in range(1, 13):
            month_data = hist_json.get(str(m))
            if month_data:
                count += 1
                for b in WIND_BINS:
                    annual[b] = annual.get(b, 0) + float(month_data.get(b, 0))
        if count > 0:
            annual = {b: round(v / count, 2) for b, v in annual.items()}
        else:
            return None
    # Dominant = en yüksek freq olan yön
    dominant = max(WIND_BINS, key=lambda b: annual.get(b, 0))
    return {"dominant": dominant, "histogram": annual}


def get_climate_for_province(
    db: Session, province: str, district: Optional[str] = None
) -> dict:
    """Tek il (ya da il+ilçe) için aylık iklim serileri.

    Climatology'de o lokasyon için kayıt varsa DB'den, yoksa mock'tan döner.
    Response şeması her durumda aynı (frontend kontrolsüz kullanır).
    """
    variants = province_aliases(province)
    q = db.query(Climatology).filter(Climatology.province_name.in_(variants))
    if district:
        q = q.filter(Climatology.district_name == district)
    else:
        q = q.filter(Climatology.district_name.is_(None))
    # Aynı il+ilçe için 3 satır var (wind/solar/hydro) — JSON'lar aynı,
    # birinden okumak yeterli.
    row = q.first()

    if not row:
        return _mock_climate_for_province(province)

    # DB'de JSON kolonların durumu — herhangi biri doluysa "db" kaynağı say
    has_any_db_data = any([
        row.monthly_precipitation,
        row.monthly_cloud_cover,
        row.monthly_sunshine_hours,
        row.wind_direction_histogram,
        row.monthly_river_discharge,
    ])

    if not has_any_db_data:
        return _mock_climate_for_province(province)

    # Mock'tan eksik field'ları doldur (kademeli geçiş için)
    mock_base = _mock_climate_for_province(province)
    out = dict(mock_base)
    out["source"] = "db"

    if row.monthly_precipitation:
        out["precipitation"] = row.monthly_precipitation
    if row.monthly_cloud_cover:
        out["cloud_cover"] = row.monthly_cloud_cover
    if row.monthly_sunshine_hours:
        out["sunshine_hours"] = row.monthly_sunshine_hours
    if row.monthly_river_discharge:
        # Format: [{mean, min, max}, × 12]
        out["river_discharge"] = row.monthly_river_discharge

    wind_rose = _wind_rose_from_histogram(row.wind_direction_histogram)
    if wind_rose:
        out["wind_rose"] = wind_rose

    return out


def get_climate_for_region(
    db: Session, region_id: str, provinces: List[str]
) -> dict:
    """Bölge için aylık iklim — illerin ortalaması.

    Bölge tab'ı için. Her ay için 81 il değil, bölgenin illeri ortalamalı.
    """
    # Her il için climate çek
    per_province = [
        get_climate_for_province(db, p, district=None) for p in provinces
    ]

    # 12 aylık serileri ortala
    def avg_series(field: str) -> List[float]:
        all_series = [p.get(field, [0] * 12) for p in per_province]
        out: List[float] = []
        for m in range(12):
            vals = [s[m] for s in all_series if m < len(s)]
            out.append(round(sum(vals) / len(vals), 2) if vals else 0)
        return out

    # Debi: sadece "mean" alanını ortala
    def avg_discharge() -> List[Dict]:
        out: List[Dict] = []
        for m in range(12):
            means = [
                p["river_discharge"][m]["mean"]
                for p in per_province
                if m < len(p.get("river_discharge", []))
            ]
            mins = [
                p["river_discharge"][m]["min"]
                for p in per_province
                if m < len(p.get("river_discharge", []))
            ]
            maxs = [
                p["river_discharge"][m]["max"]
                for p in per_province
                if m < len(p.get("river_discharge", []))
            ]
            out.append({
                "mean": round(sum(means) / len(means), 2) if means else 0,
                "min": round(sum(mins) / len(mins), 2) if mins else 0,
                "max": round(sum(maxs) / len(maxs), 2) if maxs else 0,
            })
        return out

    # Wind rose: dominant yön — illerden majority vote
    dominants = [p["wind_rose"]["dominant"] for p in per_province if p.get("wind_rose")]
    if dominants:
        from collections import Counter
        dominant = Counter(dominants).most_common(1)[0][0]
    else:
        dominant = "NW"

    # Source belirle
    db_count = sum(1 for p in per_province if p.get("source") == "db")
    if db_count == len(per_province):
        source = "db"
    elif db_count == 0:
        source = f"mock_region:{region_id}"
    else:
        source = f"hybrid_{db_count}of{len(per_province)}_db"

    return {
        "irradiance": avg_series("irradiance"),
        "wind_speed": avg_series("wind_speed"),
        "precipitation": avg_series("precipitation"),
        "temperature": avg_series("temperature"),
        "cloud_cover": avg_series("cloud_cover"),
        "sunshine_hours": avg_series("sunshine_hours"),
        "river_discharge": avg_discharge(),
        "wind_rose": _build_wind_rose_from_dominant(dominant),
        "source": source,
    }
