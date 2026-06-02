"""P3 — İklim senaryosu (RCP) delta motoru (2026-05-28).

SARIMAX baseline forecast'ı IPCC RCP senaryolarına göre ayarlar. SARIMAX
sadece geçmiş trendi extrapolate eder; iklim değişimi sinyalini (uzun-vade
ısınma + yağış rejimi değişimi) yakalayamaz. Bu modül baseline serinin
üstüne bölgesel RCP deltalarını ekler.

**Bilimsel temel (IPCC AR5/AR6, Akdeniz/Türkiye bölgesi):**
  - RCP4.5 (orta — emisyon ~2040 zirve, sonra düşüş): 2050'ye ~+1.5°C
  - RCP8.5 (yüksek — "business as usual"): 2050'ye ~+2.5°C

Türkiye Akdeniz iklim kuşağında beklenen yönelimler:
  - Güneşlenme/açık gün ↑ (bulutluluk ↓)
  - Yağış ↓ (özellikle güney/iç bölgeler)
  - Nehir debisi ↓↓ (yağış azalması + buharlaşma artışı bileşik etki)
  - Sıcaklık ↑

Deltalar **yıllık kümülatif** uygulanır: forecast başlangıç yılından
itibaren her yıl `delta_pct_per_year * year_offset` kadar baseline'a eklenir.

Bu kaba bir downscaling'dir; tam çözünürlüklü CMIP6 projeksiyonu için ERA5/
CORDEX verisi gerekir (gelecek iş). Amaç: kullanıcıya "iklim değişimi bu
metriği hangi yönde, ne büyüklükte etkiler" sezgisi vermek.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Dict, List

# Metrik bazlı yıllık % değişim (RCP senaryosu × metrik).
# Pozitif = artış, negatif = azalış. Akdeniz/Türkiye bölgesel tahminleri.
#
# Kaynak yaklaşımı: IPCC AR6 WG1 Atlas (Mediterranean) + Türkiye iklim
# projeksiyon literatürü ortalaması, yıllığa indirgenmiş.
_SCENARIO_DELTAS: Dict[str, Dict[str, float]] = {
    "rcp45": {
        "sunshine": +0.15,       # açık gün artışı
        "irradiance": +0.15,
        "cloud": -0.20,          # bulutluluk azalışı
        "precipitation": -0.30,  # yağış azalışı
        "discharge": -0.45,      # nehir debisi (bileşik)
        "wind": -0.10,           # ortalama rüzgar hızı hafif azalış (2026-06-02 B-wind)
        "temperature": +0.05,    # °C/yıl yaklaşık (oransal değil ama tutarlılık için)
    },
    "rcp85": {
        "sunshine": +0.30,
        "irradiance": +0.30,
        "cloud": -0.40,
        "precipitation": -0.55,
        "discharge": -0.80,
        "wind": -0.20,           # rüzgarda belirgin azalış (2026-06-02 B-wind)
        "temperature": +0.09,
    },
}

# Senaryo insan-okur açıklamaları (UI tooltip).
SCENARIO_META = {
    "baseline": {
        "label": "Baz Senaryo",
        "description": "Sadece geçmiş trend (SARIMAX). İklim değişimi sinyali yok.",
        "color": "#22D3EE",  # cyan
    },
    "rcp45": {
        "label": "RCP 4.5 (Orta)",
        "description": "Emisyonlar ~2040'ta zirve yapıp düşer. 2050'ye ~+1.5°C "
                       "ısınma. Akdeniz'de ılımlı kuraklaşma.",
        "color": "#FBBF24",  # amber
    },
    "rcp85": {
        "label": "RCP 8.5 (Yüksek)",
        "description": "Emisyonlar artmaya devam eder. 2050'ye ~+2.5°C ısınma. "
                       "Belirgin kuraklaşma, nehir debisinde güçlü düşüş.",
        "color": "#EF4444",  # kırmızı
    },
}


def scenario_factor(scenario: str, metric: str, year_offset: int) -> float:
    """Senaryo + metrik + yıl offset için çarpan faktörü.

    baseline → 1.0. RCP'ler için: 1 + (delta_pct_per_year/100) * year_offset.
    Batch precompute (build_ml_forecasts) ve CI ölçeklemesi için public API.
    """
    if scenario == "baseline":
        return 1.0
    delta = _SCENARIO_DELTAS.get(scenario, {}).get(metric, 0.0)
    return 1.0 + (delta / 100.0) * max(0, year_offset)


@dataclass
class ScenarioPoint:
    date: str       # ISO "YYYY-MM-01"
    value: float


@dataclass
class ScenarioSeries:
    """Tek bir senaryonun ayarlanmış serisi."""
    scenario: str             # "baseline" | "rcp45" | "rcp85"
    label: str
    description: str
    color: str
    points: List[ScenarioPoint]
    # Forecast ufkundaki son yılın baseline'a göre kümülatif % sapması
    end_delta_pct: float


def _apply_scenario(
    baseline_points: List[tuple],  # [(date_obj, value), ...]
    start_year: int,
    delta_pct_per_year: float,
) -> List[ScenarioPoint]:
    """Baseline serisine yıllık kümülatif delta uygula."""
    out: List[ScenarioPoint] = []
    for d, v in baseline_points:
        year_offset = max(0, d.year - start_year)
        factor = 1.0 + (delta_pct_per_year / 100.0) * year_offset
        out.append(ScenarioPoint(date=d.isoformat(), value=round(v * factor, 4)))
    return out


def build_scenarios(
    baseline_points: List[tuple],  # [(date_obj, value), ...] — forecast noktaları
    metric: str,
    scenarios: List[str] | None = None,
) -> Dict[str, ScenarioSeries]:
    """Baseline forecast'tan RCP senaryo serileri üret.

    Args:
        baseline_points: SARIMAX forecast noktaları [(date, value)]
        metric: "sunshine"|"irradiance"|"cloud"|"precipitation"|"discharge"
        scenarios: hangi senaryolar (default: baseline + rcp45 + rcp85)

    Returns:
        {scenario_key: ScenarioSeries}
    """
    if scenarios is None:
        scenarios = ["baseline", "rcp45", "rcp85"]
    if not baseline_points:
        return {}

    start_year = baseline_points[0][0].year
    last_year = baseline_points[-1][0].year
    horizon_years = max(1, last_year - start_year)

    result: Dict[str, ScenarioSeries] = {}
    for sc in scenarios:
        meta = SCENARIO_META.get(sc, SCENARIO_META["baseline"])
        if sc == "baseline":
            pts = [
                ScenarioPoint(date=d.isoformat(), value=round(v, 4))
                for d, v in baseline_points
            ]
            end_delta = 0.0
        else:
            delta = _SCENARIO_DELTAS.get(sc, {}).get(metric, 0.0)
            pts = _apply_scenario(baseline_points, start_year, delta)
            end_delta = round(delta * horizon_years, 2)
        result[sc] = ScenarioSeries(
            scenario=sc,
            label=meta["label"],
            description=meta["description"],
            color=meta["color"],
            points=pts,
            end_delta_pct=end_delta,
        )
    return result


def scenarios_to_dict(series_map: Dict[str, ScenarioSeries]) -> dict:
    """JSON-uyumlu dict (FastAPI response)."""
    return {
        "scenarios": [
            {
                "scenario": s.scenario,
                "label": s.label,
                "description": s.description,
                "color": s.color,
                "end_delta_pct": s.end_delta_pct,
                "points": [{"date": p.date, "value": p.value} for p in s.points],
            }
            for s in series_map.values()
        ]
    }
