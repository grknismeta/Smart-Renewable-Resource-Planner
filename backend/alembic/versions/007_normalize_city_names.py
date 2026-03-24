"""Normalize city_name variants in hourly_weather_data.

- Fix 3 typos in province names: Kinkkale→Kırıkkale, Zinguldak→Zonguldak, Gümüshane→Gümüşhane
- Merge old ASCII-format city_name records into their canonical Turkish-char forms
- Merge Kahramanmaras → K. Maras (consistent with constants.py)

Revision ID: 007_normalize_city_names
Revises: 006_add_location_code
Create Date: 2026-03-22
"""

from alembic import op

revision = '007_normalize_city_names'
down_revision = '006_add_location_code'
branch_labels = None
depends_on = None


def upgrade():
    # Typo fixes (wrong names → correct names)
    op.execute("UPDATE hourly_weather_data SET city_name = 'Kırıkkale' WHERE city_name IN ('Kinkkale', 'Kirikkale')")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Zonguldak' WHERE city_name = 'Zinguldak'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Gümüşhane' WHERE city_name IN ('Gumushane', 'Gümüshane')")

    # ASCII-to-Turkish normalization (old-format records → canonical form)
    op.execute("UPDATE hourly_weather_data SET city_name = 'Çanakkale' WHERE city_name = 'Canakkale'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Çankiri' WHERE city_name = 'Cankiri'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Çorum' WHERE city_name = 'Corum'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Düzce' WHERE city_name = 'Duzce'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Elazığ' WHERE city_name = 'Elazig'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Iğdır' WHERE city_name = 'Igdir'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'K. Maras' WHERE city_name = 'Kahramanmaras'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Karabük' WHERE city_name = 'Karabuk'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Kütahya' WHERE city_name = 'Kutahya'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Bartın' WHERE city_name = 'Bartin'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Bingöl' WHERE city_name = 'Bingol'")


def downgrade():
    # Reverse only the typo fixes (ASCII→Turkish reversals are ambiguous)
    op.execute("UPDATE hourly_weather_data SET city_name = 'Kinkkale' WHERE city_name = 'Kırıkkale'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Zinguldak' WHERE city_name = 'Zonguldak'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Gümüshane' WHERE city_name = 'Gümüşhane'")
    op.execute("UPDATE hourly_weather_data SET city_name = 'Kahramanmaras' WHERE city_name = 'K. Maras'")
