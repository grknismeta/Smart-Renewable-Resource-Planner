"""/analysis/* endpoint'leri — Climatology Tek Kaynak (Sprint S1, 2026-05-17).

Raporlar, İl Analizi, Önerilen Bölgeler ve Choropleth tümü `climatology`
tablosundan beslenir. `province_analysis` deprecated.

**Frontend signature invariant (S1 kararı):** Endpoint'lerin response
şeması DEĞİŞMEZ — frontend dokunulmadan çalışır. Climatology tek bir
statik skor üretir (`score_climatology`); eski 4 horizon (1m/3m/6m/yearly)
field'larının HEPSİ aynı değere map'lenir. Manisa örneği: skor sürekli
recompute edilmez, bölge karakteri statik.
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, func
from sqlalchemy.orm import Session

from app.db.database import get_system_db
from app.db.models import Climatology
from app.services.climate_aggregate_service import (
    get_climate_for_province,
    get_climate_for_region,
)
from app.services.district_scoring_service import get_province_centroid
from app.services.district_scoring_service import (
    get_best_spots_per_resource,
    get_districts_for_province,
)
from app.services.climatology_service import _tr_ascii_fold
from app.services.province_aliases import province_aliases

router = APIRouter(prefix="/analysis", tags=["analysis"])

# Static data dosyaları (R1 — Landing/Bölge için TR genel verisi)
_DATA_DIR = Path(__file__).resolve().parent.parent.parent / "data"


@lru_cache(maxsize=1)
def _tr_stats() -> dict:
    """TR genel istatistikleri (TEİAŞ + EPDK 2024 yıl sonu)."""
    with open(_DATA_DIR / "tr_stats.json", encoding="utf-8") as f:
        return json.load(f)


@lru_cache(maxsize=1)
def _tr_regions() -> list:
    """7 coğrafi bölge + il listesi."""
    with open(_DATA_DIR / "tr_regions.json", encoding="utf-8") as f:
        return json.load(f)["regions"]

ResourceType = Literal["wind", "solar", "hydro"]
Horizon = Literal["1m", "3m", "6m", "yearly"]


def _row_to_dict(row: Climatology) -> Dict:
    """Climatology row'unu frontend'in beklediği şemaya çevir.

    Eski `province_analysis` formatı: scores.1m/3m/6m/yearly, raw.avg_*.
    Climatology'de tek skor var — 4 horizon aynı değere işaret eder.
    """
    score = row.score_climatology
    return {
        "province_name": row.province_name,
        "resource_type": row.resource_type,
        "scores": {
            "1m": score,
            "3m": score,
            "6m": score,
            "yearly": score,
        },
        "raw": {
            "avg_wind_speed": row.avg_wind_speed_10y,
            "avg_solar_radiation": row.avg_ghi_wm2,
            "avg_temperature": row.avg_temperature_10y,
            "capacity_factor": row.capacity_factor,
        },
        "sample_count": row.sample_count_hourly,
        "computed_at": row.computed_at.isoformat() if row.computed_at else None,
    }


def _province_filter(name: str):
    """Türkçe ASCII fold ile il adını DB'de eşleştir.

    DB'de "Balıkesir" bazen "Balikesir" olarak kayıtlı. Endpoint hem orijinal
    hem fold edilmiş varyasyonu OR ile arar.
    """
    orig = name
    fold = _tr_ascii_fold(name)
    return or_(
        Climatology.province_name == orig,
        Climatology.province_name == fold,
    )


@router.get("/provinces")
def list_provinces(
    type: ResourceType = Query(..., description="wind | solar | hydro"),
    horizon: Horizon = Query("6m", description="1m | 3m | 6m | yearly (climatology'de tek statik skor — hepsi aynı)"),
    limit: Optional[int] = Query(None, ge=1, le=81, description="Top-N (opsiyonel)"),
    db: Session = Depends(get_system_db),
):
    """
    Belirli kaynak için iller (climatology skoruna göre azalan sıralı).
    İl bazlı: `district_name IS NULL`. İlçe seviyesi `/choropleth/{metric}`'te.

    Önerilen Bölgeler + Raporlar ana kaynağı.
    """
    # İl bazlı: district_name NULL (ilçe değil)
    q = (
        db.query(Climatology)
        .filter(
            Climatology.resource_type == type,
            Climatology.district_name.is_(None),
        )
        .order_by(Climatology.score_climatology.desc().nullslast())
    )
    rows = q.limit(limit).all() if limit else q.all()

    items = [_row_to_dict(r) for r in rows]
    return {
        "resource_type": type,
        "horizon": horizon,
        "count": len(items),
        "items": items,
    }


@router.get("/province/{name}")
def province_detail(
    name: str,
    db: Session = Depends(get_system_db),
):
    """
    Tek il — 3 kaynak × 4 horizon (climatology'de 1 statik skor → 4 horizon aynı).
    İl Analizi ekranı ana kaynağı.
    """
    rows = (
        db.query(Climatology)
        .filter(
            _province_filter(name),
            Climatology.district_name.is_(None),
        )
        .all()
    )
    if not rows:
        raise HTTPException(
            status_code=404,
            detail=(
                f"İl '{name}' için henüz climatology verisi yok. "
                "(Pilot fazda 8 il hesaplandı; tüm 81 il için "
                "`climatology_compute_all` script'i çalıştırılmalı.)"
            ),
        )

    by_resource = {r.resource_type: _row_to_dict(r) for r in rows}
    return {
        "province_name": name,
        "resources": by_resource,
    }


@router.get("/choropleth/{metric}")
def choropleth(
    metric: ResourceType,
    horizon: Horizon = Query("6m", description="1m | 3m | 6m | yearly (statik skor — hepsi aynı)"),
    db: Session = Depends(get_system_db),
):
    """
    Harita choropleth katmanı için `province_name → score` map.
    Frontend renklendirmesi tek aramayla dolu liste alsın.
    """
    rows = (
        db.query(
            Climatology.province_name,
            Climatology.score_climatology.label("score"),
        )
        .filter(
            Climatology.resource_type == metric,
            Climatology.district_name.is_(None),
        )
        .all()
    )
    scores: Dict[str, Optional[float]] = {r.province_name: r.score for r in rows}
    valid = [s for s in scores.values() if s is not None]
    return {
        "metric": metric,
        "horizon": horizon,
        "count": len(scores),
        "min": min(valid) if valid else None,
        "max": max(valid) if valid else None,
        "scores": scores,
    }


# ── Aşama 3.D: ML Projeksiyonu ──────────────────────────────────────────────

@router.get("/projection")
def projection(
    province: str = Query(..., description="İl adı (Manisa, İzmir vb.)"),
    metric: str = Query(
        "wind_speed",
        regex="^(wind_speed|shortwave_radiation|temperature)$",
        description="wind_speed | shortwave_radiation | temperature",
    ),
    horizon_days: int = Query(
        90, description="Tahmin penceresi: 30 | 90 | 180 | 365"
    ),
):
    """Geçmiş günlük veriden seçili metrik için gelecek tahmini.

    Yöntem: seasonal naive (DoY ortalaması) + lineer trend. Geçmiş 5+ yıllık
    veri varsa yıllık trend hesaplanır; yoksa sadece mevsimsel ortalama.

    Yanıt: günlük tahmin listesi + 95% güven aralığı + meta. UI eğri grafiği
    olarak gösterir; varsayım ve sınırlar `disclaimer` alanında.
    """
    from app.services.ml_projection_service import (
        project_province,
        project_to_dict,
        VALID_HORIZONS,
    )

    if horizon_days not in VALID_HORIZONS:
        raise HTTPException(
            status_code=400,
            detail=f"horizon_days {sorted(VALID_HORIZONS)} arasında olmalı",
        )
    try:
        proj = project_province(province, metric, horizon_days)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except RuntimeError as re:
        raise HTTPException(status_code=503, detail=str(re))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Projeksiyon hatası: {e}")
    return project_to_dict(proj)


# ── R1: Landing Tab Data ─────────────────────────────────────────────────────

# Frontend "wind" string'ini DB'deki "Rüzgar Türbini"... vs ile eşleştirmek
# gerekmez — climatology resource_type zaten "wind"/"solar"/"hydro" tutuyor.
_RESOURCE_LABELS = {"wind": "Rüzgar", "solar": "Güneş", "hydro": "Hidro"}


def _top_province_for_resource(db: Session, resource: str, limit: int) -> List[Dict]:
    """En yüksek score_climatology'li N il (district_name IS NULL)."""
    rows = (
        db.query(Climatology)
        .filter(
            Climatology.resource_type == resource,
            Climatology.district_name.is_(None),
        )
        .order_by(Climatology.score_climatology.desc().nullslast())
        .limit(limit)
        .all()
    )
    return [
        {
            "province_name": r.province_name,
            "score": round(r.score_climatology, 2) if r.score_climatology else 0,
            "capacity_factor": round(r.capacity_factor, 3) if r.capacity_factor else None,
            "avg_wind_speed": round(r.avg_wind_speed_10y, 2) if r.avg_wind_speed_10y else None,
            "avg_ghi": round(r.avg_ghi_wm2, 1) if r.avg_ghi_wm2 else None,
        }
        for r in rows
    ]


@router.get("/landing")
def landing(
    top_n: int = Query(10, ge=1, le=20, description="Her kaynak için top-N il"),
    db: Session = Depends(get_system_db),
):
    """Landing tab için tek-istek veri paketi.

    Döner:
    - `tr_stats`: TR genel istatistikleri (TEİAŞ + EPDK 2024)
    - `regions`: 7 coğrafi bölge (statik meta) + climatology score özeti
    - `top_provinces`: Her kaynak (wind/solar/hydro) için top-N il
    - `overall_top`: Tüm kaynaklar arasında en yüksek skorlu top-N il
    """
    stats = _tr_stats()
    regions_meta = _tr_regions()

    # Her kaynak için top-N
    top_by_resource = {
        res: _top_province_for_resource(db, res, top_n)
        for res in ("wind", "solar", "hydro")
    }

    # Overall: tüm kaynakların score'larından en yüksek N (province bazlı tek satır)
    # Bir il birden fazla kaynakta yüksek skora sahip olabilir; her ilin maksimum
    # skoru + o skorun ait olduğu kaynak alınır.
    rows = (
        db.query(
            Climatology.province_name,
            Climatology.resource_type,
            Climatology.score_climatology,
        )
        .filter(
            Climatology.district_name.is_(None),
            Climatology.score_climatology.isnot(None),
        )
        .all()
    )
    per_province: Dict[str, Dict] = {}
    for prov, rtype, score in rows:
        if prov not in per_province or score > per_province[prov]["score"]:
            per_province[prov] = {
                "province_name": prov,
                "top_resource": rtype,
                "score": round(float(score), 2),
            }
    overall_top = sorted(
        per_province.values(), key=lambda x: x["score"], reverse=True
    )[:top_n]

    # Region özeti: climatology'den bölgenin il'lerinin ortalama skoru +
    # bölgenin lider kaynağı (her bölge için topResource zaten statik dosyada).
    # DB'de iller hem Türkçe hem ASCII-fold edilmiş halde olabiliyor
    # (örn. Balıkesir + Balikesir ayrı satırlar). province_aliases ile her
    # ilin tüm varyasyonlarını IN filtresine dahil ediyoruz.
    regions_out = []
    for r in regions_meta:
        all_variants: List[str] = []
        for p in r["provinces"]:
            all_variants.extend(province_aliases(p))
        avg_scores = {}
        for res in ("wind", "solar", "hydro"):
            avg = (
                db.query(func.avg(Climatology.score_climatology))
                .filter(
                    Climatology.resource_type == res,
                    Climatology.district_name.is_(None),
                    Climatology.province_name.in_(all_variants),
                )
                .scalar()
            )
            avg_scores[res] = round(float(avg), 2) if avg else None
        regions_out.append(
            {
                **r,
                "avg_scores": avg_scores,
            }
        )

    return {
        "tr_stats": stats,
        "regions": regions_out,
        "top_provinces": top_by_resource,
        "overall_top": overall_top,
    }


@router.get("/region/{region_id}")
def region_detail(
    region_id: str,
    db: Session = Depends(get_system_db),
):
    """Tek bölge için detaylı veri.

    Döner:
    - Bölge statik meta (tr_regions.json'dan)
    - Bölgenin illerinin climatology özeti (3 kaynak için score + raw)
    - Bölgenin lider 5 ili (en yüksek lider-kaynak skoru)
    """
    regions = _tr_regions()
    region = next((r for r in regions if r["id"] == region_id), None)
    if not region:
        raise HTTPException(status_code=404, detail=f"Bölge bulunamadı: {region_id}")

    provinces = region["provinces"]

    # province_aliases ile DB'deki tüm varyasyonları topla (ASCII fold dahil)
    variants_to_canonical: Dict[str, str] = {}
    for p in provinces:
        for v in province_aliases(p):
            variants_to_canonical[v] = p

    rows = (
        db.query(Climatology)
        .filter(
            Climatology.district_name.is_(None),
            Climatology.province_name.in_(list(variants_to_canonical.keys())),
        )
        .all()
    )

    # Province × resource pivot — canonical (Türkçe) il adıyla aggregate.
    # Her ile harita için merkez koordinat (centroid) eklenir.
    by_province: Dict[str, Dict] = {}
    for p in provinces:
        entry: Dict = {"province_name": p}
        centroid = get_province_centroid(p)
        if centroid:
            entry["lat"] = centroid["lat"]
            entry["lon"] = centroid["lon"]
        by_province[p] = entry
    for r in rows:
        canonical = variants_to_canonical.get(r.province_name, r.province_name)
        by_province[canonical][r.resource_type] = {
            "score": round(r.score_climatology, 2) if r.score_climatology else None,
            "capacity_factor": round(r.capacity_factor, 3) if r.capacity_factor else None,
            "avg_wind_speed": round(r.avg_wind_speed_10y, 2) if r.avg_wind_speed_10y else None,
            "avg_ghi": round(r.avg_ghi_wm2, 1) if r.avg_ghi_wm2 else None,
        }

    # Bölgenin aylık iklim aggregate'i (illerin ortalaması)
    climate = get_climate_for_region(db, region_id, provinces)

    return {
        "region": region,
        "provinces": list(by_province.values()),
        "climate": climate,
    }


@router.get("/province/{name}/climate")
def province_climate(
    name: str,
    district: Optional[str] = Query(
        None, description="İlçe adı (opsiyonel — yoksa il bazlı agg.)"
    ),
    db: Session = Depends(get_system_db),
):
    """İl (ya da il+ilçe) için aylık iklim serileri.

    Climatology DB'de yeni JSON kolonları (Migration 016) doluysa oradan,
    aksi halde `data/mock_climate_regional.json`'dan bölge bazlı template
    döner. Frontend response şemasını tek olarak kullanır.

    Hava tab + Santral tab "Production Timeline" için tek kaynak.
    """
    return get_climate_for_province(db, name, district)


@router.get("/province/{name}/districts")
def province_districts(
    name: str,
    db: Session = Depends(get_system_db),
):
    """İlin ilçeleri için 3 kaynak (GES/RES/HES) skoru + en iyi sahalar.

    İl Analizi tab'ı v3 için:
    - `districts`: tüm ilçeler (skor + best_resource + tahmini MW)
    - `best_spots`: her kaynak için top-4 ilçe (3 kolon gösterimi)

    Climatology DB'de district_name dolu satır varsa oradan; yoksa il
    bazlı skoru baseline alıp deterministic noise ile sentetik üretilir.
    """
    districts = get_districts_for_province(db, name)
    if not districts:
        raise HTTPException(
            status_code=404,
            detail=f"İl için ilçe bulunamadı: {name}",
        )
    best_spots = get_best_spots_per_resource(db, name, top_n=4)
    return {
        "province": name,
        "district_count": len(districts),
        "districts": districts,
        "best_spots": best_spots,
    }
