"""
Eksik sütunları PostgreSQL'e ekleyen migration scripti.
Sorun: SQLAlchemy modeli güncellendi ama DB tabloları güncellenmemişti.

Eksik sütunlar:
  - pins: city, district, water_body_name
  - scenarios: battery_capacity_kwh, battery_efficiency_pct, battery_cost_usd_per_kwh

Kullanım: python migrate_add_missing_columns.py
"""
import os
import psycopg2

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db",
)

MIGRATIONS = [
    # --- pins tablosu ---
    ("pins", "city",             "ALTER TABLE pins ADD COLUMN IF NOT EXISTS city VARCHAR;"),
    ("pins", "district",         "ALTER TABLE pins ADD COLUMN IF NOT EXISTS district VARCHAR;"),
    ("pins", "water_body_name",  "ALTER TABLE pins ADD COLUMN IF NOT EXISTS water_body_name VARCHAR;"),

    # --- scenarios tablosu ---
    ("scenarios", "battery_capacity_kwh",    "ALTER TABLE scenarios ADD COLUMN IF NOT EXISTS battery_capacity_kwh FLOAT;"),
    ("scenarios", "battery_efficiency_pct",  "ALTER TABLE scenarios ADD COLUMN IF NOT EXISTS battery_efficiency_pct FLOAT;"),
    ("scenarios", "battery_cost_usd_per_kwh","ALTER TABLE scenarios ADD COLUMN IF NOT EXISTS battery_cost_usd_per_kwh FLOAT;"),
]

def run():
    print(f"Bağlanıyor: {DATABASE_URL}\n")
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True
    cur = conn.cursor()

    for table, column, sql in MIGRATIONS:
        try:
            cur.execute(sql)
            print(f"  ✓  {table}.{column} eklendi (veya zaten vardı)")
        except Exception as e:
            print(f"  ✗  {table}.{column} HATA: {e}")

    cur.close()
    conn.close()
    print("\nMigration tamamlandı. Backend'i yeniden başlatın.")

if __name__ == "__main__":
    run()
