"""Normalize old-format city_name records to use province names.

Old-format records have city_name = district city name (e.g., 'Akyurt', 'Amasra')
instead of the province name ('Ankara', 'Bartın'). This migration updates those
city_names to the canonical province name from constants.py.

Also fixes the Kastamonu/Pınarbası location_code bug (was 'kay8', should be 'kas12').

Revision ID: 008_normalize_old_format_city_names
Revises: 007_normalize_city_names
Create Date: 2026-03-22
"""

from alembic import op
from sqlalchemy import text
import sys, os

revision = '008_norm_city_names'
down_revision = '007_normalize_city_names'
branch_labels = None
depends_on = None


def _build_city_to_province():
    backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    if backend_dir not in sys.path:
        sys.path.insert(0, backend_dir)
    from app.core.constants import TURKEY_CITIES

    name_to_province = {}
    for c in TURKEY_CITIES:
        name = c.get('name') or ''
        province = c.get('province') or ''
        if name and province:
            name_to_province[name] = province

    province_names = {c.get('province', '') for c in TURKEY_CITIES}
    # Only map names that are NOT themselves province names
    return {k: v for k, v in name_to_province.items() if k not in province_names}


def upgrade():
    conn = op.get_bind()
    updates = _build_city_to_province()

    updated_total = 0
    for city_name, province_name in updates.items():
        result = conn.execute(
            text("UPDATE hourly_weather_data SET city_name = :prov "
                 "WHERE city_name = :city"),
            {"prov": province_name, "city": city_name},
        )
        updated_total += result.rowcount

    print(f"[008] Normalized {updated_total} old-format city_name records")

    # Fix specific backfill bug: Kastamonu/Pınarbası was assigned kay8 (Kayseri)
    # Correct code is kas12 (Kastamonu)
    conn.execute(
        text("UPDATE hourly_weather_data SET location_code = 'kas12' "
             "WHERE city_name = 'Kastamonu' AND location_code = 'kay8'")
    )


def downgrade():
    pass
