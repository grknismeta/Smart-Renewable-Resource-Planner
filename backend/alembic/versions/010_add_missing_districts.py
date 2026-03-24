"""Add missing districts: Zonguldak(Kilimli, Kozlu), Samsun(Atakum, Canik, İlkadım)
   + fix location_codes shifted by new alphabetical positions
   + fix Zonguldak Ereğli coordinates (was pointing to Konya Ereğli)

Revision ID: 010_add_missing_districts
Revises: 009_composite_indexes
Create Date: 2026-03-22
"""

from alembic import op
import sqlalchemy as sa

revision = '010_add_missing_districts'
down_revision = '009_composite_indexes'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    1. Yeni eklenen ilçeler (Kilimli, Kozlu, Atakum, Canik, İlkadım) henüz
       veritabanında kayıt içermez — sadece constants.py'e eklendi.
       Bir sonraki veri çekiminde otomatik doldurulacaklar.

    2. Mevcut ilçelerin location_code'ları, yeni ilçelerin alfabetik sıraya
       girmesiyle kaydı. Aşağıdaki UPDATE'ler bu kaymayı düzeltir.

    Zonguldak:
       Çaycuma: zon5 → zon7

    Samsun:
       Ayvacık:       sam3  → sam4
       Bafra:         sam4  → sam5
       Havza:         sam5  → sam7
       Kavak:         sam6  → sam8
       Ladik:         sam7  → sam9
       Ondokuz Mayıs: sam8  → sam10
       Salıpazarı:    sam9  → sam11
       Tekkeköy:      sam10 → sam12
       Terme:         sam11 → sam13
       Vezirköprü:    sam12 → sam14
       Yakakent:      sam13 → sam15
       Çarşamba:      sam14 → sam16

    3. Zonguldak Ereğli koordinat düzeltmesi (Konya Ereğli'sine işaret ediyordu).
    """
    conn = op.get_bind()

    # Zonguldak Ereğli koordinat düzeltmesi (Kdz. Ereğli: 41.2831, 31.4266)
    conn.execute(sa.text("""
        DELETE FROM hourly_weather_data 
        WHERE city_name = 'Zonguldak' AND district_name = 'Ereğli' 
        AND (latitude != 41.2831 OR longitude != 31.4266)
        AND EXISTS (
            SELECT 1 FROM hourly_weather_data h2 
            WHERE h2.latitude = 41.2831 AND h2.longitude = 31.4266 
            AND h2.timestamp = hourly_weather_data.timestamp
        )
    """))

    conn.execute(sa.text("""
        UPDATE hourly_weather_data 
        SET latitude = 41.2831, longitude = 31.4266 
        WHERE city_name = 'Zonguldak' AND district_name = 'Ereğli'
        AND (latitude != 41.2831 OR longitude != 31.4266)
    """))

    updates = [
        ('Zonguldak', 'Çaycuma', 'zon5', 'zon7'),
        ('Samsun', 'Çarşamba', 'sam14', 'sam16'),
        ('Samsun', 'Yakakent', 'sam13', 'sam15'),
        ('Samsun', 'Vezirköprü', 'sam12', 'sam14'),
        ('Samsun', 'Terme', 'sam11', 'sam13'),
        ('Samsun', 'Tekkeköy', 'sam10', 'sam12'),
        ('Samsun', 'Salıpazarı', 'sam9', 'sam11'),
        ('Samsun', 'Ondokuz Mayıs', 'sam8', 'sam10'),
        ('Samsun', 'Ladik', 'sam7', 'sam9'),
        ('Samsun', 'Kavak', 'sam6', 'sam8'),
        ('Samsun', 'Havza', 'sam5', 'sam7'),
        ('Samsun', 'Bafra', 'sam4', 'sam5'),
        ('Samsun', 'Ayvacık', 'sam3', 'sam4')
    ]

    for city, district, old_code, new_code in updates:
        # Prevent UNIQUE CONSTRAINT conflict by deleting old records that overlap with existing new_code data
        conn.execute(sa.text(f"""
            DELETE FROM hourly_weather_data 
            WHERE city_name = '{city}' AND district_name = '{district}' 
            AND location_code = '{old_code}'
            AND EXISTS (
                SELECT 1 FROM hourly_weather_data h2 
                WHERE h2.location_code = '{new_code}' 
                AND h2.timestamp = hourly_weather_data.timestamp
            )
        """))
        
        # Update the remaining records safely
        conn.execute(sa.text(f"""
            UPDATE hourly_weather_data 
            SET location_code = '{new_code}' 
            WHERE city_name = '{city}' AND district_name = '{district}' 
            AND location_code = '{old_code}'
        """))


def downgrade() -> None:
    conn = op.get_bind()

    updates = [
        ('Zonguldak', 'Çaycuma', 'zon7', 'zon5'),
        ('Samsun', 'Ayvacık', 'sam4', 'sam3'),
        ('Samsun', 'Bafra', 'sam5', 'sam4'),
        ('Samsun', 'Havza', 'sam7', 'sam5'),
        ('Samsun', 'Kavak', 'sam8', 'sam6'),
        ('Samsun', 'Ladik', 'sam9', 'sam7'),
        ('Samsun', 'Ondokuz Mayıs', 'sam10', 'sam8'),
        ('Samsun', 'Salıpazarı', 'sam11', 'sam9'),
        ('Samsun', 'Tekkeköy', 'sam12', 'sam10'),
        ('Samsun', 'Terme', 'sam13', 'sam11'),
        ('Samsun', 'Vezirköprü', 'sam14', 'sam12'),
        ('Samsun', 'Yakakent', 'sam15', 'sam13'),
        ('Samsun', 'Çarşamba', 'sam16', 'sam14')
    ]

    for city, district, current_code, old_code in updates:
        conn.execute(sa.text(f"""
            DELETE FROM hourly_weather_data 
            WHERE city_name = '{city}' AND district_name = '{district}' 
            AND location_code = '{current_code}'
            AND EXISTS (
                SELECT 1 FROM hourly_weather_data h2 
                WHERE h2.location_code = '{old_code}' 
                AND h2.timestamp = hourly_weather_data.timestamp
            )
        """))
        conn.execute(sa.text(f"""
            UPDATE hourly_weather_data 
            SET location_code = '{old_code}' 
            WHERE city_name = '{city}' AND district_name = '{district}' 
            AND location_code = '{current_code}'
        """))
