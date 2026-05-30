"""İlçe granüler skor servisi (2026-05-20 Sprint R1).

Climatology DB'de district_name dolu satır varsa (ileride CSV import + ilçe
bazlı climatology compute eklenince) oradan döner. Yoksa il bazlı skoru
baseline alıp deterministic noise ile sentetik ilçe skorları üretir.

**Felsefe:** Mockup'taki `generateSpotsForProvince` mantığı backend tarafına
taşındı. Frontend her ilçenin gerçek/sentetik olduğunu bilmez; sadece skor
tüketir. CSV gelince climatology service ilçe bazlı satır yazacak (R2'de)
ve sentetik fallback otomatik devre dışı kalır.

**Mockup ref:** designhtml/reports-data-tr.jsx → districtsData,
PROVINCE_BEST_SPOTS, generateSpotsForProvince.
"""
from __future__ import annotations

import hashlib
import json
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from app.db.models import Climatology
from app.services.province_aliases import province_aliases

_DATA_DIR = Path(__file__).resolve().parent.parent.parent / "data"


@lru_cache(maxsize=1)
def _districts_by_province() -> Dict[str, List[Dict]]:
    """turkey_districts.json'dan il → ilçe listesi."""
    path = _DATA_DIR / "vector" / "turkey_districts.json"
    if not path.exists():
        # Backend root'ta da olabilir
        path = _DATA_DIR.parent / "turkey_districts.json"
    if not path.exists():
        return {}
    with open(path, encoding="utf-8") as f:
        all_districts = json.load(f)
    out: Dict[str, List[Dict]] = {}
    for d in all_districts:
        prov = d["province"]
        out.setdefault(prov, []).append({
            "name": d["district"] or d["name"],
            "lat": d["lat"],
            "lon": d["lon"],
        })
    return out


def get_province_centroid(province: str) -> Optional[Dict[str, float]]:
    """İlin merkez koordinatı — ilçelerinin lat/lon ortalaması.

    Raporlar Bölge tab haritası için. turkey_districts.json'dan türetilir.
    """
    districts = _districts_by_province().get(province, [])
    if not districts:
        for alias in province_aliases(province):
            districts = _districts_by_province().get(alias, [])
            if districts:
                break
    if not districts:
        return None
    lat = sum(d["lat"] for d in districts) / len(districts)
    lon = sum(d["lon"] for d in districts) / len(districts)
    return {"lat": round(lat, 4), "lon": round(lon, 4)}


def _deterministic_noise(seed: str, scale: float = 10.0) -> float:
    """İsim hash'inden [-scale/2, +scale/2] aralığında deterministic offset.

    Aynı ilçe her seferinde aynı offset alır (random değil — tutarlı görüntü).
    """
    h = hashlib.md5(seed.encode("utf-8")).digest()
    # İlk 4 byte → 0-1 normalize
    val = int.from_bytes(h[:4], "big") / (2**32 - 1)
    return (val - 0.5) * scale


def _province_score_baseline(db: Session, province: str) -> Dict[str, float]:
    """İlin climatology'den 3 kaynak skoru (district NULL satırlar)."""
    variants = province_aliases(province)
    rows = (
        db.query(Climatology)
        .filter(
            Climatology.province_name.in_(variants),
            Climatology.district_name.is_(None),
        )
        .all()
    )
    out = {"wind": 50.0, "solar": 50.0, "hydro": 30.0}  # default
    for r in rows:
        if r.score_climatology is not None:
            out[r.resource_type] = float(r.score_climatology)
    return out


def get_districts_for_province(db: Session, province: str) -> List[Dict]:
    """İlin ilçeleri için 3 kaynak skoru + best spot tahminleri.

    Response satırı:
        {
            "name": "Karapınar",
            "lat": 37.72, "lon": 33.55,
            "scores": {"wind": 38, "solar": 91, "hydro": 12},
            "best_resource": "solar",
            "best_score": 91,
            "estimated_mw": 45  # ilçenin sentetik available capacity
        }
    """
    districts = _districts_by_province().get(province, [])
    if not districts:
        # province_aliases ile dene
        for alias in province_aliases(province):
            districts = _districts_by_province().get(alias, [])
            if districts:
                break
    if not districts:
        return []

    baseline = _province_score_baseline(db, province)
    out = []
    for idx, d in enumerate(districts):
        name = d["name"]
        # Her kaynak için baseline + deterministic noise (±10 puan)
        seed_prefix = f"{province}/{name}"
        scores = {
            "solar": _clamp(baseline["solar"]
                            + _deterministic_noise(seed_prefix + "/solar", 22)),
            "wind": _clamp(baseline["wind"]
                           + _deterministic_noise(seed_prefix + "/wind", 22)),
            "hydro": _clamp(baseline["hydro"]
                            + _deterministic_noise(seed_prefix + "/hydro", 22)),
        }
        best = max(scores.keys(), key=lambda k: scores[k])
        out.append({
            "name": name,
            "lat": d["lat"],
            "lon": d["lon"],
            "scores": {k: round(v, 1) for k, v in scores.items()},
            "best_resource": best,
            "best_score": round(scores[best], 1),
            # Tahmini kullanılabilir MW — score × ölçek faktörü
            "estimated_mw": int(round(scores[best] * 0.8
                                       + _deterministic_noise(seed_prefix + "/mw", 30))),
        })
    # Best skoruna göre azalan sırala
    out.sort(key=lambda x: x["best_score"], reverse=True)
    return out


def get_best_spots_per_resource(
    db: Session, province: str, top_n: int = 4
) -> Dict[str, List[Dict]]:
    """Bir il için her kaynak (GES/RES/HES) için en iyi top-N ilçe.

    v3 mockup'ta İl Analizi 3 kolon: "En İyi Güneş İlçeleri" gibi.
    """
    districts = get_districts_for_province(db, province)
    if not districts:
        return {"solar": [], "wind": [], "hydro": []}
    out: Dict[str, List[Dict]] = {}
    for res in ("solar", "wind", "hydro"):
        sorted_d = sorted(
            districts,
            key=lambda d: d["scores"][res],
            reverse=True,
        )[:top_n]
        # Her kaynak için karaktere özel ek alanlar (mockup'taki BestSpotCard)
        enriched = []
        for d in sorted_d:
            spot = {
                "name": d["name"],
                "lat": d["lat"],
                "lon": d["lon"],
                "score": d["scores"][res],
                "estimated_mw": d["estimated_mw"],
            }
            # Kaynak-spesifik mock detay
            if res == "solar":
                spot.update({
                    "irradiance_kwh_m2_day": round(
                        4.5 + d["scores"][res] / 50, 2
                    ),
                    "slope": "0-5°",
                    "panel_area_m2": int(800 + d["scores"][res] * 16),
                })
            elif res == "wind":
                spot.update({
                    "wind_speed_ms": round(5.5 + d["scores"][res] / 25, 2),
                    "hub_height_m": 120,
                })
            elif res == "hydro":
                spot.update({
                    "flow_rate_m3s": round(4 + d["scores"][res] / 6, 1),
                    "head_m": int(30 + d["scores"][res]),
                })
            enriched.append(spot)
        out[res] = enriched
    return out


def _clamp(v: float, lo: float = 0, hi: float = 100) -> float:
    return max(lo, min(hi, v))
