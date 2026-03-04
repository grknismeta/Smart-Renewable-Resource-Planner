"""
SRRP — SQLite → PostgreSQL Veri Migrasyonu
==========================================
Mevcut SQLite verilerini PostgreSQL'e aktarır.
Kullanım: python -m scripts.migrate_sqlite_to_postgres
"""
import sqlite3
import os
import sys

# Backend dizinini path'e ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.db.database import engine, Base, SessionLocal
from app.db.models import (
    User, Pin, PinAnalysis, Scenario,
    Equipment, GridAnalysis, WeatherData, HourlyWeatherData,
    PinCalculationResult
)

# --- SQLite Dosya Yolları ---
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQLITE_FILES = {
    "system": os.path.join(BACKEND_DIR, "system_data.db"),
    "user": os.path.join(BACKEND_DIR, "user_data.db"),
    "user_pins": os.path.join(BACKEND_DIR, "user_pins_data.db"),
}


def get_sqlite_connection(db_key: str):
    """SQLite veritabanına bağlan."""
    path = SQLITE_FILES[db_key]
    if not os.path.exists(path):
        print(f"  ⚠️  {db_key} dosyası bulunamadı: {path}")
        return None
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def migrate_table(sqlite_conn, pg_session, table_name: str, model_class, batch_size: int = 1000):
    """Bir tabloyu SQLite'dan PostgreSQL'e aktar."""
    try:
        cursor = sqlite_conn.execute(f"SELECT * FROM {table_name}")
        columns = [desc[0] for desc in cursor.description]
    except sqlite3.OperationalError as e:
        print(f"  ⚠️  Tablo '{table_name}' bulunamadı: {e}")
        return 0

    rows = cursor.fetchall()
    if not rows:
        print(f"  ⏭️  {table_name}: Boş tablo, atlanıyor")
        return 0

    count = 0
    batch = []
    
    # Model'in sahip olduğu column isimlerini al
    model_columns = {c.key for c in model_class.__table__.columns}

    for row in rows:
        data = {}
        for col in columns:
            if col in model_columns:
                data[col] = row[col]
        
        batch.append(model_class(**data))
        count += 1

        if len(batch) >= batch_size:
            pg_session.bulk_save_objects(batch)
            pg_session.commit()
            batch = []

    if batch:
        pg_session.bulk_save_objects(batch)
        pg_session.commit()

    print(f"  ✅ {table_name}: {count} kayıt aktarıldı")
    return count


def main():
    print("=" * 60)
    print("  SRRP — SQLite → PostgreSQL Veri Migrasyonu")
    print("=" * 60)

    # 1. PostgreSQL tablolarını oluştur
    print("\n📦 PostgreSQL tabloları oluşturuluyor...")
    Base.metadata.create_all(bind=engine)
    print("  ✅ Tablolar oluşturuldu")

    pg_session = SessionLocal()
    total = 0

    try:
        # 2. System DB migrasyonu
        print("\n🔧 System DB migrasyonu (system_data.db)...")
        sys_conn = get_sqlite_connection("system")
        if sys_conn:
            total += migrate_table(sys_conn, pg_session, "equipments", Equipment)
            total += migrate_table(sys_conn, pg_session, "grid_analyses", GridAnalysis)
            total += migrate_table(sys_conn, pg_session, "weather_data", WeatherData)
            total += migrate_table(sys_conn, pg_session, "hourly_weather_data", HourlyWeatherData)
            sys_conn.close()

        # 3. User DB migrasyonu
        print("\n👤 User DB migrasyonu (user_data.db)...")
        user_conn = get_sqlite_connection("user")
        if user_conn:
            total += migrate_table(user_conn, pg_session, "users", User)
            total += migrate_table(user_conn, pg_session, "pins", Pin)
            total += migrate_table(user_conn, pg_session, "pin_analyses", PinAnalysis)
            total += migrate_table(user_conn, pg_session, "scenarios", Scenario)
            user_conn.close()

        # 4. User Pins DB migrasyonu
        print("\n📌 User Pins DB migrasyonu (user_pins_data.db)...")
        pins_conn = get_sqlite_connection("user_pins")
        if pins_conn:
            total += migrate_table(pins_conn, pg_session, "pin_calculation_results", PinCalculationResult)
            pins_conn.close()

        # 5. PostgreSQL sequence'ları güncelle (auto-increment doğru çalışsın)
        print("\n🔄 Sequence'lar güncelleniyor...")
        tables_to_fix = [
            "users", "pins", "pin_analyses", "scenarios",
            "equipments", "grid_analyses", "weather_data",
            "hourly_weather_data", "pin_calculation_results"
        ]
        for table in tables_to_fix:
            try:
                pg_session.execute(text(
                    f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), "
                    f"COALESCE(MAX(id), 0) + 1, false) FROM {table}"
                ))
            except Exception:
                pass  # Tablo yoksa veya boşsa sorun yok
        pg_session.commit()
        print("  ✅ Sequence'lar güncellendi")

    except Exception as e:
        pg_session.rollback()
        print(f"\n❌ Migrasyon hatası: {e}")
        raise
    finally:
        pg_session.close()

    print(f"\n{'=' * 60}")
    print(f"  ✅ Migrasyon tamamlandı! Toplam: {total} kayıt aktarıldı")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
