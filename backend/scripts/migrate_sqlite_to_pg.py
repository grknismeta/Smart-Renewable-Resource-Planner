"""
SQLite → PostgreSQL Migration Script
Transfers all data from old SQLite databases to PostgreSQL (srrp_db).
"""
import sqlite3
import os
import sys
import time

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text, inspect
from sqlalchemy.orm import sessionmaker

# === CONFIG ===
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PG_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db"
)

SQLITE_FILES = {
    "system": os.path.join(BACKEND_DIR, "system_data.db"),
    "user": os.path.join(BACKEND_DIR, "user_data.db"),
    "pins": os.path.join(BACKEND_DIR, "user_pins_data.db"),
}

# Table mappings: (sqlite_db_key, sqlite_table, pg_table, column_mapping)
# column_mapping: dict of {sqlite_col: pg_col} or None for auto-match
MIGRATIONS = [
    # 1. System tables (order matters for FK constraints)
    {
        "source_db": "system",
        "source_table": "equipments",
        "target_table": "equipments",
        "col_map": None,  # auto
        "batch_size": 100,
    },
    # SKIP WEATHER DATA
    # {
    #     "source_db": "system",
    #     "source_table": "weather_data",
    #     "target_table": "weather_data",
    #     "col_map": None,
    #     "batch_size": 10000,  # Large table: 1.99M rows
    # },
    # {
    #     "source_db": "system",
    #     "source_table": "hourly_weather_data",
    #     "target_table": "hourly_weather_data",
    #     "col_map": None,
    #     "batch_size": 5000,  # 269K rows
    # },
    {
        "source_db": "system",
        "source_table": "grid_analyses",
        "target_table": "grid_analyses",
        "col_map": None,
        "batch_size": 500,
    },
    # 2. User tables
    {
        "source_db": "user",
        "source_table": "users",
        "target_table": "users",
        "col_map": None,
        "batch_size": 100,
    },
    {
        "source_db": "user",
        "source_table": "pins",
        "target_table": "pins",
        "col_map": None,
        "batch_size": 100,
    },
    {
        "source_db": "user",
        "source_table": "pin_analyses",
        "target_table": "pin_analyses",
        "col_map": None,
        "batch_size": 100,
    },
    {
        "source_db": "user",
        "source_table": "scenarios",
        "target_table": "scenarios",
        "col_map": None,
        "batch_size": 100,
    },
    # 3. Pin calculation results
    {
        "source_db": "pins",
        "source_table": "pin_calculation_results",
        "target_table": "pin_calculation_results",
        "col_map": None,
        "batch_size": 100,
    },
]


def get_sqlite_conn(db_key):
    path = SQLITE_FILES[db_key]
    if not os.path.exists(path):
        raise FileNotFoundError(f"SQLite DB not found: {path}")
    return sqlite3.connect(path)


def get_pg_engine():
    engine = create_engine(PG_URL, pool_pre_ping=True)
    # Test connection
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return engine


def get_sqlite_columns(cursor, table):
    """Get column names from SQLite table."""
    cols = cursor.execute(f"PRAGMA table_info([{table}])").fetchall()
    return [c[1] for c in cols]


def get_pg_columns(engine, table):
    """Get column names from PostgreSQL table."""
    insp = inspect(engine)
    if not insp.has_table(table):
        return []
    cols = insp.get_columns(table)
    return [c["name"] for c in cols]


def migrate_table(pg_engine, migration):
    """Migrate a single table from SQLite to PostgreSQL."""
    db_key = migration["source_db"]
    src_table = migration["source_table"]
    tgt_table = migration["target_table"]
    batch_size = migration["batch_size"]
    col_map = migration.get("col_map")

    print(f"\n{'='*60}")
    print(f"  Migrating: {db_key}.{src_table} → PostgreSQL.{tgt_table}")
    print(f"{'='*60}")

    # Get SQLite data
    try:
        sqlite_conn = get_sqlite_conn(db_key)
    except FileNotFoundError as e:
        print(f"  ⚠️ SKIP: {e}")
        return 0

    sqlite_cursor = sqlite_conn.cursor()
    sqlite_cols = get_sqlite_columns(sqlite_cursor, src_table)

    # Get PostgreSQL columns
    pg_cols = get_pg_columns(pg_engine, tgt_table)
    if not pg_cols:
        print(f"  ⚠️ SKIP: PostgreSQL table '{tgt_table}' does not exist")
        sqlite_conn.close()
        return 0

    # Build column mapping (intersection of SQLite and PG columns)
    if col_map:
        # Custom mapping
        common_cols = [(s, col_map.get(s, s)) for s in sqlite_cols if col_map.get(s, s) in pg_cols]
    else:
        # Auto mapping (same column names)
        common_cols = [(c, c) for c in sqlite_cols if c in pg_cols]

    if not common_cols:
        print(f"  ⚠️ SKIP: No matching columns")
        sqlite_conn.close()
        return 0

    src_col_names = [c[0] for c in common_cols]
    tgt_col_names = [c[1] for c in common_cols]

    # Check existing row count in PostgreSQL
    with pg_engine.connect() as conn:
        pg_count = conn.execute(text(f"SELECT COUNT(*) FROM {tgt_table}")).scalar()
    
    if pg_count > 0:
        print(f"  ℹ️ PostgreSQL table already has {pg_count} rows")
        print(f"  🧹 Clearing existing data...")
        with pg_engine.connect() as conn:
            conn.execute(text(f"DELETE FROM {tgt_table}"))
            conn.commit()

    # Get total row count from SQLite
    total_rows = sqlite_cursor.execute(f"SELECT COUNT(*) FROM [{src_table}]").fetchone()[0]
    print(f"  📊 Source: {total_rows} rows, {len(common_cols)} columns")
    print(f"  📋 Columns: {', '.join(src_col_names)}")

    if total_rows == 0:
        print(f"  ⚠️ SKIP: No data to migrate")
        sqlite_conn.close()
        return 0

    # Migrate in batches
    select_sql = f"SELECT {', '.join(f'[{c}]' for c in src_col_names)} FROM [{src_table}]"
    sqlite_cursor.execute(select_sql)

    migrated = 0
    start_time = time.time()

    while True:
        rows = sqlite_cursor.fetchmany(batch_size)
        if not rows:
            break

        # Build insert statement
        placeholders = ", ".join([f":{c}" for c in tgt_col_names])
        insert_sql = text(
            f"INSERT INTO {tgt_table} ({', '.join(tgt_col_names)}) "
            f"VALUES ({placeholders})"
        )

        # Convert rows to dicts
        batch_data = []
        for row in rows:
            row_dict = {}
            for i, col_name in enumerate(tgt_col_names):
                val = row[i]
                # Handle JSON fields stored as strings in SQLite
                if isinstance(val, str) and val.startswith(('[', '{')):
                    import json
                    try:
                        val = json.loads(val)
                    except:
                        pass
                row_dict[col_name] = val
            batch_data.append(row_dict)

        with pg_engine.connect() as conn:
            conn.execute(insert_sql, batch_data)
            conn.commit()

        migrated += len(rows)
        elapsed = time.time() - start_time
        rate = migrated / elapsed if elapsed > 0 else 0
        pct = (migrated / total_rows) * 100

        # Progress every 10k rows or for small tables
        if migrated % (batch_size * 5) == 0 or migrated == total_rows or total_rows < 1000:
            print(f"  ✅ {migrated:,}/{total_rows:,} ({pct:.1f}%) — {rate:.0f} rows/s")

    elapsed = time.time() - start_time
    print(f"  ✅ Done! {migrated:,} rows in {elapsed:.1f}s")

    # Reset sequence for auto-increment
    try:
        with pg_engine.connect() as conn:
            max_id = conn.execute(text(f"SELECT MAX(id) FROM {tgt_table}")).scalar()
            if max_id:
                conn.execute(text(
                    f"SELECT setval(pg_get_serial_sequence('{tgt_table}', 'id'), {max_id})"
                ))
                conn.commit()
    except Exception as e:
        print(f"  ⚠️ Sequence reset: {e}")

    sqlite_conn.close()
    return migrated


def main():
    print("=" * 60)
    print("  🔄 SQLite → PostgreSQL Migration")
    print("=" * 60)

    # Verify PostgreSQL connection
    try:
        pg_engine = get_pg_engine()
        print(f"✅ PostgreSQL connected: {PG_URL.split('@')[1] if '@' in PG_URL else PG_URL}")
    except Exception as e:
        print(f"❌ PostgreSQL connection failed: {e}")
        return

    # Verify SQLite files
    for key, path in SQLITE_FILES.items():
        exists = os.path.exists(path)
        size = os.path.getsize(path) / (1024*1024) if exists else 0
        print(f"  {'✅' if exists else '❌'} {key}: {path} ({size:.1f} MB)")

    # Ensure PostgreSQL tables exist
    try:
        from app.db.database import Base, engine as app_engine
        from app.db import models  # This registers all models
        Base.metadata.create_all(bind=pg_engine)
        print("✅ PostgreSQL tables created/verified")
    except Exception as e:
        print(f"⚠️ Table creation via models: {e}")
        print("  Tables should already exist if backend ran once")

    # Run migrations
    total_migrated = 0
    start = time.time()

    for migration in MIGRATIONS:
        try:
            count = migrate_table(pg_engine, migration)
            total_migrated += count
        except Exception as e:
            print(f"  ❌ Error: {e}")
            import traceback
            traceback.print_exc()

    elapsed = time.time() - start
    print(f"\n{'='*60}")
    print(f"  🎉 Migration Complete!")
    print(f"  Total: {total_migrated:,} rows in {elapsed:.1f}s")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
