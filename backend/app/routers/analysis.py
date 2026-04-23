"""/analysis/* endpoint'leri — Tek Kaynak (Faz 1).

Raporlar, İl Analizi, Önerilen Bölgeler ve Choropleth tümü `province_analysis`
tablosundan beslenir. Eski canlı hesaplama path'leri burada kullanılmaz.
"""

from __future__ import annotations

from typing import Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.database import get_system_db
from app.db.models import ProvinceAnalysis

router = APIRouter(prefix="/analysis", tags=["analysis"])

ResourceType = Literal["wind", "solar", "hydro"]
Horizon = Literal["1m", "3m", "6m", "yearly"]

HORIZON_COLUMN = {
    "1m": ProvinceAnalysis.score_1m,
    "3m": ProvinceAnalysis.score_3m,
    "6m": ProvinceAnalysis.score_6m,
    "yearly": ProvinceAnalysis.score_yearly,
}


def _row_to_dict(row: ProvinceAnalysis) -> Dict:
    return {
        "province_name": row.province_name,
        "resource_type": row.resource_type,
        "scores": {
            "1m": row.score_1m,
            "3m": row.score_3m,
            "6m": row.score_6m,
            "yearly": row.score_yearly,
        },
        "raw": {
            "avg_wind_speed": row.avg_wind_speed,
            "avg_solar_radiation": row.avg_solar_radiation,
            "avg_temperature": row.avg_temperature,
            "capacity_factor": row.capacity_factor,
        },
        "sample_count": row.sample_count,
        "computed_at": row.computed_at.isoformat() if row.computed_at else None,
    }


def _score_column(horizon: str):
    col = HORIZON_COLUMN.get(horizon)
    if col is None:
        raise HTTPException(
            status_code=400,
            detail=f"Geçersiz horizon '{horizon}'. Beklenen: 1m|3m|6m|yearly",
        )
    return col


@router.get("/provinces")
def list_provinces(
    type: ResourceType = Query(..., description="wind | solar | hydro"),
    horizon: Horizon = Query("6m", description="1m | 3m | 6m | yearly"),
    limit: Optional[int] = Query(None, ge=1, le=81, description="Top-N (opsiyonel)"),
    db: Session = Depends(get_system_db),
):
    """
    Belirli kaynak + pencere için iller. Skora göre azalan sıralı.
    `limit` verilirse top-N döner; verilmezse 81 ilin tamamı.

    Önerilen Bölgeler ve Raporlar ana kaynağı.
    """
    score_col = _score_column(horizon)

    q = (
        db.query(ProvinceAnalysis)
        .filter(ProvinceAnalysis.resource_type == type)
        .order_by(score_col.desc().nullslast())
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
    Tek il — 3 kaynak × 4 pencere skor + ham metrikler.
    İl Analizi ekranı ana kaynağı.
    """
    rows = (
        db.query(ProvinceAnalysis)
        .filter(ProvinceAnalysis.province_name == name)
        .all()
    )
    if not rows:
        raise HTTPException(
            status_code=404,
            detail=f"İl '{name}' için henüz analiz verisi yok (scheduler ilk çalışmayı bekliyor olabilir).",
        )

    by_resource = {r.resource_type: _row_to_dict(r) for r in rows}
    return {
        "province_name": name,
        "resources": by_resource,
    }


@router.get("/choropleth/{metric}")
def choropleth(
    metric: ResourceType,
    horizon: Horizon = Query("6m"),
    db: Session = Depends(get_system_db),
):
    """
    Harita choropleth katmanı için `province_name → score` map.
    Frontend renklendirmesi tek aramayla dolu liste alsın.
    """
    score_col = _score_column(horizon)
    rows = (
        db.query(
            ProvinceAnalysis.province_name,
            score_col.label("score"),
        )
        .filter(ProvinceAnalysis.resource_type == metric)
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
