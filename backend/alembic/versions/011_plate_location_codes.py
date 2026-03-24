"""Plaka tabanlı location_code sistemi

3 harfli il kodları (ada0, sam14 vb.) → plaka numarası tabanlı format
(01000, 55016 vb.) olarak güncellenir.

Aynı zamanda yeni büyükşehir ilçeleri için yer açılır:
  Efeler(09), Altıeylül+Karesi(10), Merkezefendi+Pamukkale(20),
  Artuklu(47), Menteşe(48), Süleymanpaşa(59), Altınordu(52),
  Şehzadeler+Yunusemre(45).

Revision ID: 011_plate_location_codes
Revises: 010_add_missing_districts
Create Date: 2026-03-22
"""

from alembic import op
import sqlalchemy as sa

revision = '011_plate_location_codes'
down_revision = '010_add_missing_districts'
branch_labels = None
depends_on = None


def _build_new_code_map():
    """
    TURKEY_CITIES listesini kullanarak (city_name, district_name) → new_code
    eşlemesini oluşturur. Migration anında constants.py zaten güncel olduğu
    için doğrudan import edilir.
    """
    from app.core.constants import TURKEY_CITIES
    mapping = {}
    for city in TURKEY_CITIES:
        code = city.get("code")
        if code:
            key = (city["province"], city.get("district"))  # district=None for centers
            mapping[key] = code
    return mapping


def upgrade() -> None:
    conn = op.get_bind()

    # Yeni kodları hesapla
    code_map = _build_new_code_map()

    # İl merkezleri (district_name IS NULL)
    # city_name = province, district_name = NULL → new_code = {plate:02d}000
    center_updates = [
        (prov, code)
        for (prov, dist), code in code_map.items()
        if dist is None
    ]

    # İlçeler (district_name IS NOT NULL)
    district_updates = [
        (prov, dist, code)
        for (prov, dist), code in code_map.items()
        if dist is not None
    ]

    # İl merkezlerini güncelle
    for city_name, new_code in center_updates:
        conn.execute(sa.text("""
            UPDATE hourly_weather_data
            SET location_code = :new_code
            WHERE city_name = :city_name
              AND district_name IS NULL
              AND location_code != :new_code
        """), {"new_code": new_code, "city_name": city_name})

    # İlçeleri güncelle
    for city_name, district_name, new_code in district_updates:
        conn.execute(sa.text("""
            UPDATE hourly_weather_data
            SET location_code = :new_code
            WHERE city_name = :city_name
              AND district_name = :district_name
              AND location_code != :new_code
        """), {"new_code": new_code, "city_name": city_name, "district_name": district_name})


def downgrade() -> None:
    """
    Downgrade desteklenmiyor — plaka sistemine geçiş geri alınamaz.
    Eski sistemdeki 3 harfli kodlar regenerate edilemez çünkü constants.py
    artık plaka tabanlı. Manuel geri alım için yedeğe bakınız.
    """
    raise NotImplementedError(
        "Plaka sisteminden geri dönüş desteklenmiyor. "
        "Eski DB yedeğini geri yükleyin."
    )
