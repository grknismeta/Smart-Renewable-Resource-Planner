"""
SRRP — restricted_zones Backfill (Aşama B-4)
============================================

OSM Overpass API'den Türkiye için koruma altındaki alanları çekip
``restricted_zones`` PostGIS tablosuna yazar.

Çekilen feature türleri:
  * ``boundary=protected_area`` (genel koruma alanları)
  * ``boundary=national_park`` (milli parklar — TR'de ayrı tag)
  * ``leisure=nature_reserve`` (doğa rezervi)
  * ``landuse=military`` (askeri bölge)
  * ``military=*`` (askeri tesis - bina/sınır)

Pin yerleştirirken GeoService bu polygonları sorgular → "Yasaklı bölge:
{name}" uyarısı **gerçek veri** ile çıkar (eskiden tablo boştu, sadece
veri olmadığı için tüm pin'ler "uygun" görünüyordu).

Kullanım
--------

.. code-block:: bash

    cd backend
    .\\venv\\Scripts\\python.exe scripts/backfill_restricted_zones.py

Tahmini süre: 30-60 sn (Overpass query + ~3-5K polygon insert).
İdempotent değil — tabloyu önce TRUNCATE eder. Yeniden çalıştırılabilir.
"""
from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

import requests

# Backend modüllerini import etmek için path
_BACKEND_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_BACKEND_ROOT))

from sqlalchemy import text  # noqa: E402

from app.db.database import _engine  # noqa: E402

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] %(message)s")
logger = logging.getLogger(__name__)


OVERPASS_ENDPOINT = "https://overpass-api.de/api/interpreter"

# Türkiye bbox: GADM TR_0 sınırlarına yakın geniş bir kutu
# Kıbrıs ve Batı Trakya gibi sınır bölgeleri dahil
TR_BBOX = "(35.5,25.5,42.5,45.0)"  # (south,west,north,east)

OVERPASS_QUERY = f"""
[out:json][timeout:180];
(
  // Korunan alanlar (milli park, doğa rezervi, biyosfer)
  way["boundary"="protected_area"]{TR_BBOX};
  relation["boundary"="protected_area"]{TR_BBOX};
  way["boundary"="national_park"]{TR_BBOX};
  relation["boundary"="national_park"]{TR_BBOX};
  way["leisure"="nature_reserve"]{TR_BBOX};
  relation["leisure"="nature_reserve"]{TR_BBOX};

  // Askeri bölgeler
  way["landuse"="military"]{TR_BBOX};
  relation["landuse"="military"]{TR_BBOX};
  way["military"]{TR_BBOX};
  relation["military"]{TR_BBOX};
);
out geom;
"""


def fetch_osm_data() -> dict:
    """Overpass API'den veriyi çek. ~30-60 sn sürebilir.

    Overpass Tier-1 sunucusu User-Agent ve Accept header'ları ister
    (yanlış formatta 406 Not Acceptable döner).
    """
    logger.info("[overpass] Sorgu gönderiliyor (kapsam: TR + komşu sınır)...")
    t0 = time.monotonic()
    headers = {
        "User-Agent": "SRRP-Backfill/1.0 (smart-renewable-resource-planner)",
        "Accept": "application/json",
    }
    # Body'yi form-encoded değil raw POST gönder
    response = requests.post(
        OVERPASS_ENDPOINT,
        data=OVERPASS_QUERY.encode("utf-8"),
        headers=headers,
        timeout=300,
    )
    if response.status_code != 200:
        logger.error(
            "[overpass] HTTP %d — body: %s",
            response.status_code, response.text[:300],
        )
    response.raise_for_status()
    data = response.json()
    elapsed = time.monotonic() - t0
    logger.info(
        "[overpass] %d element alındı (%.1fs)",
        len(data.get("elements", [])),
        elapsed,
    )
    return data


def _classify(tags: dict) -> tuple[str, str | None]:
    """OSM tag'lerine göre (feature_type, name) döndür."""
    name = tags.get("name") or tags.get("name:tr") or tags.get("name:en")

    if tags.get("boundary") == "national_park":
        return ("national_park", name)
    if tags.get("boundary") == "protected_area":
        return ("protected_area", name)
    if tags.get("leisure") == "nature_reserve":
        return ("nature_reserve", name)
    if tags.get("landuse") == "military" or tags.get("military"):
        return ("military", name or tags.get("military") or None)
    # Fallback
    return ("restricted", name)


def _osm_geom_to_wkt(element: dict) -> str | None:
    """OSM way/relation'dan WKT polygon string üret.

    Way:      coordinates listesi → POLYGON
    Relation: members listesi → MULTIPOLYGON (basit birleştirme)
    """
    el_type = element.get("type")

    if el_type == "way":
        geom = element.get("geometry", [])
        if len(geom) < 3:
            return None
        coords = [(p["lon"], p["lat"]) for p in geom]
        # Polygon kapatma — son nokta ilk noktadan farklıysa ekle
        if coords[0] != coords[-1]:
            coords.append(coords[0])
        ring = ", ".join(f"{lon} {lat}" for lon, lat in coords)
        return f"POLYGON(({ring}))"

    if el_type == "relation":
        rings = []
        for m in element.get("members", []):
            if m.get("type") != "way":
                continue
            geom = m.get("geometry", [])
            if len(geom) < 3:
                continue
            coords = [(p["lon"], p["lat"]) for p in geom]
            if coords[0] != coords[-1]:
                coords.append(coords[0])
            ring = ", ".join(f"{lon} {lat}" for lon, lat in coords)
            rings.append(f"(({ring}))")
        if not rings:
            return None
        if len(rings) == 1:
            return f"POLYGON{rings[0]}"
        return f"MULTIPOLYGON({', '.join(rings)})"

    return None


def insert_into_db(elements: list[dict]) -> int:
    """OSM elementlerini PostGIS'e yaz. INSERT öncesi tabloyu boşaltır.

    Savepoint pattern (`begin_nested`) ile her INSERT ayrı bir alt-transaction
    içinde — bir INSERT başarısız olursa sadece o satır rollback edilir,
    önceki başarılı insertler korunur.
    """
    inserted = 0
    skipped = 0
    geom_invalid = 0

    with _engine.begin() as conn:
        # 0. Tabloyu temizle
        logger.info("[db] restricted_zones tablosu boşaltılıyor (TRUNCATE)...")
        conn.execute(text("TRUNCATE TABLE restricted_zones"))

        # 1. Element'leri sırayla insert (savepoint pattern)
        for el in elements:
            tags = el.get("tags") or {}
            ftype, name = _classify(tags)
            wkt = _osm_geom_to_wkt(el)
            if not wkt:
                skipped += 1
                continue

            sp = conn.begin_nested()  # SAVEPOINT
            try:
                conn.execute(text("""
                    INSERT INTO restricted_zones (geom, feature_type, name, description, min_zoom)
                    VALUES (
                        ST_Multi(
                            ST_CollectionExtract(
                                ST_MakeValid(ST_GeomFromText(:wkt, 4326)),
                                3   -- 3 = polygon only (point/line at’ar)
                            )
                        ),
                        :ftype,
                        :name,
                        :description,
                        :min_zoom
                    )
                """), {
                    "wkt": wkt,
                    "ftype": ftype,
                    "name": name,
                    "description": tags.get("operator") or tags.get("designation"),
                    "min_zoom": 7,
                })
                sp.commit()
                inserted += 1
            except Exception as e:
                sp.rollback()
                err = str(e)
                if "requires more points" in err or "Invalid" in err:
                    geom_invalid += 1
                else:
                    logger.warning(
                        "[db] Insert hatası (id=%s, type=%s): %s",
                        el.get("id"), ftype, err[:120],
                    )
                skipped += 1

    logger.info(
        "[db] Insert tamam: %d eklendi, %d atlandı (%d geçersiz geometri)",
        inserted, skipped, geom_invalid,
    )
    return inserted


def main():
    logger.info("=== restricted_zones backfill başlatılıyor ===")

    # 1. Overpass'tan çek
    try:
        data = fetch_osm_data()
    except Exception as e:
        logger.error("[overpass] Hata: %s", e)
        sys.exit(1)

    elements = data.get("elements", [])
    if not elements:
        logger.warning("[overpass] Hiç element gelmedi — bbox veya query yanlış olabilir")
        sys.exit(1)

    # 2. PostGIS'e yaz
    inserted = insert_into_db(elements)

    # 3. Doğrulama
    with _engine.connect() as c:
        total = c.execute(text("SELECT COUNT(*) FROM restricted_zones")).scalar()
        by_type = c.execute(text("""
            SELECT feature_type, COUNT(*) AS cnt
            FROM restricted_zones
            GROUP BY feature_type
            ORDER BY cnt DESC
        """)).fetchall()

    logger.info("=== TAMAMLANDI ===")
    logger.info("Toplam %d kayıt yazıldı.", total)
    for row in by_type:
        logger.info("  %s: %d", row[0], row[1])


if __name__ == "__main__":
    main()
