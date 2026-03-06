from fastapi import APIRouter, Depends, HTTPException, Path
from fastapi.responses import Response
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import Optional

from ..db.database import get_system_db
from ..services.redis_cache import REDIS_URL, REDIS_AVAILABLE

import redis

router = APIRouter()

# Binary cache için parse_responses=False kullanacak bir client oluşturalım.
# Çünkü redis_cache.py içindeki client decode_responses=True ile çalışıyor ve PBF binary döndüğünde utf-8 decode hatası veriyor.
binary_redis = None
if REDIS_AVAILABLE:
    try:
        binary_redis = redis.from_url(REDIS_URL, decode_responses=False)
    except:
        pass

# Katman adı - Tablo adı eşleşmesi
LAYER_TO_TABLE = {
    "hydro": "hydro_features",
    "restricted": "restricted_zones",
    "energy": "energy_corridors"
}

@router.get("/{layer_name}/{z}/{x}/{y}.pbf")
async def get_vector_tile(
    layer_name: str = Path(..., description="Name of the layer (e.g. hydro, restricted, energy)"),
    z: int = Path(..., description="Zoom level"),
    x: int = Path(..., description="X coordinate"),
    y: int = Path(..., description="Y coordinate"),
    db: Session = Depends(get_system_db)
):
    table_name = LAYER_TO_TABLE.get(layer_name)
    if not table_name:
        raise HTTPException(status_code=404, detail=f"Layer '{layer_name}' not found.")

    # Redis Cache Kontrolü (Binary PBF için özel)
    cache_key = f"mvt:{layer_name}:{z}:{x}:{y}"
    if binary_redis:
        try:
            cached_tile = binary_redis.get(cache_key)
            if cached_tile:
                # Binary veriyi cache'den alıp direkt dön
                return Response(
                    content=cached_tile, 
                    media_type="application/x-protobuf",
                    headers={
                        "X-Cache": "HIT",
                        "Access-Control-Allow-Origin": "*"
                    }
                )
        except Exception as e:
            pass # Cache hatasını görmezden gel ve DB'ye devam et

    # 1. Bounding Box hesabı z,x,y'den
    # PostGIS ST_TileEnvelope fonksiyonunu kullanıyoruz (4326 yerine 3857 dönmesini bekler)
    # Çoğu tile sistemi Web Mercator (3857) kullanır. Bu nedenle veriyi de uçakta 3857'ye dönüştürüp ST_AsMVTGeom'a vermeliyiz.
    
    # 3. TABLOYA GÖRE DİNAMİK SÜTUN (PROPERTY) SEÇİMİ
    # Hata düzeltildi: is_restricted ve energy_capacity_mw şimdilik çıkarıldı.
    # Haritayı çizmek için sadece feature_type ve min_zoom yeterlidir.
    # DÜZELTME: Veritabanında min_zoom NULL ise görünmez olmasını engellemek için COALESCE ile varsayılan 0 atıyoruz.
    properties = "t.feature_type, COALESCE(t.min_zoom, 0) as min_zoom"
        
    query = text(f"""
        WITH bounds AS (
            SELECT ST_TileEnvelope(:z, :x, :y) AS geom
        ),
        mvtgeom AS (
            SELECT ST_AsMVTGeom(
                ST_Transform(t.geom, 3857), 
                bounds.geom, 
                4096, 
                256, 
                true
            ) AS geom,
            {properties}
            FROM {table_name} t, bounds
            WHERE ST_Intersects(t.geom, ST_Transform(bounds.geom, 4326))
              AND COALESCE(t.min_zoom, 0) <= :z
        )
        SELECT ST_AsMVT(mvtgeom.*, :layer_name) AS tile
        FROM mvtgeom;
    """)

    result = db.execute(query, {
        "z": z, 
        "x": x, 
        "y": y, 
        "layer_name": layer_name
    }).fetchone()

    tile = result[0] if result else None

    if not tile:
        # Boş tile döner
        return Response(
            status_code=204,
            headers={"Access-Control-Allow-Origin": "*"}
        )

    # İşlenen binary tile'ı Redis'e at (Ömür: 24 Saat)
    if binary_redis:
        try:
            binary_redis.setex(cache_key, 86400, tile)
        except Exception:
            pass

    return Response(
        content=tile, 
        media_type="application/x-protobuf",
        headers={
            "X-Cache": "MISS",
            "Access-Control-Allow-Origin": "*"
        }
    )