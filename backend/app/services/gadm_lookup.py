"""
GADM Polygon Adı Lookup Servisi (1.A2.c-fix4)
=============================================

Animation endpoint'i ve diğer choropleth-tabanlı katmanlar için **tek
otoriter kaynak** = `data/vector/turkey_districts_osm.geojson`. Bu dosyada
NAME_1 (il) + NAME_2 (ilçe) Türkçe karakterli, tam yazımlı ve frontend
MapLibre polygon source'undaki ad ile birebir aynı.

DB tarafı tarihsel olarak farklı yazımlar kullanır:

    DB                  GADM
    --                  ----
    Adiyaman      ↔     Adıyaman      (Türkçe karakter farkı)
    Afyon         ↔     Afyonkarahisar (kısaltma)
    K. Maras      ↔     Kahramanmaraş  (kısaltma + Türkçe)
    Merkez        ↔     "<İl> Merkez"  (suffix farkı)

Bu modül DB ham adını GADM kanonik adına çevirir. Animation key'leri
GADM formatında üretilir → polygon match %100 çalışır, siyah ilçe
kalmaz.
"""
from __future__ import annotations

import json
import logging
from functools import lru_cache
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Default GADM/OSM dosyası — borders.py de bu dosyayı kullanıyor
_DEFAULT_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "data" / "vector" / "turkey_districts_osm.geojson"
)


def _tr_normalize(s: str) -> str:
    """Türkçe karakterleri ASCII'ye çevir + lowercase + boşlukları temizle.

    'Adıyaman'  →  'adiyaman'
    'Afyonkarahisar' → 'afyonkarahisar'
    'İstanbul' → 'istanbul'
    'Kahramanmaraş' → 'kahramanmaras'
    """
    if not s:
        return ""
    table = str.maketrans({
        "ç": "c", "Ç": "c",
        "ğ": "g", "Ğ": "g",
        "ı": "i", "İ": "i", "I": "i",
        "ö": "o", "Ö": "o",
        "ş": "s", "Ş": "s",
        "ü": "u", "Ü": "u",
        "â": "a", "Â": "a",
        "î": "i", "Î": "i",
        "û": "u", "Û": "u",
    })
    return s.translate(table).lower().replace(".", "").replace("  ", " ").strip()


# DB'de yaygın kullanılan kısaltma → GADM tam adı
# (manuel düzelt — Türkçe normalize tek başına yeterli değil)
_PROVINCE_ALIASES_NORM_TO_GADM_NORM = {
    # DB → GADM (her ikisi de normalize edilmiş)
    "afyon": "afyonkarahisar",
    "k maras": "kahramanmaras",
    "kmaras": "kahramanmaras",
    "kahramanmaras": "kahramanmaras",  # zaten aynı
}


@lru_cache(maxsize=1)
def _load_gadm_districts() -> dict[str, list[str]]:
    """GADM dosyasını oku — il → [ilçe, ...] dict döner.

    İlk çağrıda ~50ms (geojson parse). Sonraki çağrılar `lru_cache`'den
    O(1) → animation endpoint her tetikte ücretsiz.

    Returns:
        {"İstanbul": ["Adalar", "Arnavutköy", ...], "Ankara": [...], ...}
    """
    path = _DEFAULT_PATH
    if not path.exists():
        logger.warning("[gadm_lookup] %s bulunamadi", path)
        return {}

    by_province: dict[str, list[str]] = {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for feat in data.get("features", []):
            p = feat.get("properties", {}) or {}
            n1 = p.get("NAME_1") or p.get("name_1") or p.get("province")
            n2 = p.get("NAME_2") or p.get("name_2") or p.get("district")
            if n1 and n2:
                by_province.setdefault(str(n1), []).append(str(n2))
        logger.info(
            "[gadm_lookup] Yuklendi: %d il, %d ilce",
            len(by_province), sum(len(v) for v in by_province.values()),
        )
    except Exception as e:
        logger.exception("[gadm_lookup] GADM dosyasi okunamadi: %s", e)
    return by_province


@lru_cache(maxsize=1)
def _province_norm_to_gadm() -> dict[str, str]:
    """{normalize(GADM): GADM canonical} mapping — DB→GADM çevirimi için."""
    return {_tr_normalize(p): p for p in _load_gadm_districts().keys()}


def resolve_province(db_province: Optional[str]) -> Optional[str]:
    """DB ham province adını GADM kanonik adına çevirir.

    Pipeline:
        1. Hızlı yol: aynısı GADM'de varsa direkt döndür
        2. Türkçe normalize → GADM normalize map'inden ara
        3. Alias map (Afyon → Afyonkarahisar gibi)
        4. Bulamazsa orijinali döndür (geri uyum, log uyarısı yok)

    Returns:
        GADM kanonik adı veya None (input None ise)
    """
    if not db_province:
        return db_province
    gadm_provinces = _load_gadm_districts()
    # 1. Direkt match
    if db_province in gadm_provinces:
        return db_province
    # 2. Türkçe normalize
    norm = _tr_normalize(db_province)
    direct = _province_norm_to_gadm().get(norm)
    if direct:
        return direct
    # 3. Alias map
    aliased = _PROVINCE_ALIASES_NORM_TO_GADM_NORM.get(norm)
    if aliased:
        return _province_norm_to_gadm().get(aliased) or db_province
    # 4. Fallback
    return db_province


def get_districts(gadm_province: str) -> list[str]:
    """Bir GADM ilinin tüm GADM ilçe adlarını döner."""
    return list(_load_gadm_districts().get(gadm_province, []))


@lru_cache(maxsize=1)
def all_keys() -> set[str]:
    """Tüm GADM polygon key'leri (`İl|İlçe` formatında).

    Backend her frame'de bu set'in tamamına değer atayabilir, ama atamak
    zorunda değil — atanmamış key'ler frontend'de polygon siyah görünür.
    """
    by_prov = _load_gadm_districts()
    out: set[str] = set()
    for prov, dists in by_prov.items():
        for d in dists:
            out.add(f"{prov}|{d}")
    return out


# DB ilçe adı → GADM kanonik ilçe adı için per-province normalize lookup
@lru_cache(maxsize=128)
def _district_norm_lookup_for(gadm_province: str) -> dict[str, str]:
    """{normalize(GADM ilçe): GADM ilçe} mapping — bir il için."""
    districts = _load_gadm_districts().get(gadm_province, [])
    return {_tr_normalize(d): d for d in districts}


def resolve_district(
    gadm_province: str,
    db_district: Optional[str],
) -> Optional[str]:
    """DB ilçe adını GADM kanonik ilçe adına çevirir (il bağlamında).

    Özel durum: `db_district == 'Merkez'` ise GADM'de `'<İl> Merkez'`
    formatında ilçe varsa onu döndür (örn. 'Adıyaman' → 'Adıyaman Merkez').
    """
    if not db_district:
        return None
    districts = _load_gadm_districts().get(gadm_province, [])
    if not districts:
        return None
    # 1. Direkt match
    if db_district in districts:
        return db_district
    # 2. Türkçe normalize
    norm = _tr_normalize(db_district)
    lookup = _district_norm_lookup_for(gadm_province)
    direct = lookup.get(norm)
    if direct:
        return direct
    # 3. "Merkez" → "<İl> Merkez" özel durumu
    if norm == "merkez":
        prov_merkez_norm = _tr_normalize(f"{gadm_province} Merkez")
        return lookup.get(prov_merkez_norm)
    # 4. Fallback yok — None döner, caller atlar
    return None
