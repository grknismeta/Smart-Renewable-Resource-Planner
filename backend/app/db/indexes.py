"""
SRRP Performans Index'leri (1.D)
================================

Mevcut tablolar üzerinde idempotent ``CREATE INDEX IF NOT EXISTS`` çalıştırır.

SQLAlchemy ``Base.metadata.create_all`` mevcut tabloya yeni index ekleyemediği
için, büyüme sonrası performans kritik query'leri burada manuel ele alıyoruz.

Çağrı yeri: ``app/main.py`` startup event (FastAPI başladığında bir kez).
İdempotent — tekrar tekrar çağrılabilir, var olan index'leri görmezden gelir.

Index seçim mantığı:
  * **BRIN** on ``hourly_weather_data.timestamp`` — sequential time-series için
    btree'den 1000× küçük, çok hızlı range scan; choropleth + summary
    ``WHERE timestamp >= cutoff`` query'lerinin tipik durumu.
  * Composite ``(city_name, timestamp DESC)`` — il bazlı son N saat sorguları
    için; index-only scan'a yakın performans.
  * Composite ``(district_name, timestamp DESC)`` — district-summary için.
  * ``weather_data (province_name, district_name, date)`` — daily animation
    ilçe-key payload için.

Başarısız index oluşturma uygulamayı kırmaz — log'lanır, devam edilir.
"""
from __future__ import annotations

import logging
from sqlalchemy import text

from app.db.database import SystemEngine

logger = logging.getLogger(__name__)


# Tüm index'ler idempotent — IF NOT EXISTS ile.
# Sıra: en kritik (en sık tetiklenen query'leri optimize eden) önce.
_INDEX_STATEMENTS: list[tuple[str, str]] = [
    (
        "ix_hwd_timestamp_brin",
        "CREATE INDEX IF NOT EXISTS ix_hwd_timestamp_brin "
        "ON hourly_weather_data USING BRIN (timestamp)",
    ),
    (
        "ix_hwd_city_ts_desc",
        "CREATE INDEX IF NOT EXISTS ix_hwd_city_ts_desc "
        "ON hourly_weather_data (city_name, timestamp DESC)",
    ),
    (
        "ix_hwd_district_ts_desc",
        "CREATE INDEX IF NOT EXISTS ix_hwd_district_ts_desc "
        "ON hourly_weather_data (district_name, timestamp DESC) "
        "WHERE district_name IS NOT NULL",
    ),
    (
        "ix_hwd_loccode_ts",
        "CREATE INDEX IF NOT EXISTS ix_hwd_loccode_ts "
        "ON hourly_weather_data (location_code, timestamp DESC)",
    ),
    (
        "ix_wd_province_district_date",
        "CREATE INDEX IF NOT EXISTS ix_wd_province_district_date "
        "ON weather_data (province_name, district_name, date) "
        "WHERE province_name IS NOT NULL AND district_name IS NOT NULL",
    ),
]


def ensure_performance_indexes() -> None:
    """Tüm performans index'lerini idempotent olarak oluşturur.

    FastAPI startup event'inden çağrılır. Hata logger.warning olarak yazılır,
    uygulama crash etmez (eksik index = yavaş, ama servis ayakta).
    """
    created = 0
    skipped = 0
    failed = 0
    with SystemEngine.connect() as conn:
        for name, ddl in _INDEX_STATEMENTS:
            try:
                # CREATE INDEX IF NOT EXISTS DDL — idempotent.
                # Postgres tarafında varsa NOTICE log'lar (silent).
                conn.execute(text(ddl))
                conn.commit()
                # NOTICE'ı yakalayamayız ama IF NOT EXISTS sayesinde sorun yok.
                created += 1
            except Exception as e:
                failed += 1
                logger.warning(
                    "[indexes] '%s' oluşturulamadı: %s",
                    name, e,
                )
        # Mevcut index istatistiklerini ANALYZE et (planner için)
        try:
            conn.execute(text("ANALYZE hourly_weather_data"))
            conn.execute(text("ANALYZE weather_data"))
            conn.commit()
        except Exception as e:
            logger.warning("[indexes] ANALYZE başarısız: %s", e)

    logger.info(
        "[indexes] Performans index taraması tamam — denenen=%d, başarısız=%d",
        created, failed,
    )
