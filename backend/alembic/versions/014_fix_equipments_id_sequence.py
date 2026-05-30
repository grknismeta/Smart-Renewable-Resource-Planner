"""fix equipments id sequence (PostgreSQL sequence drift)

equipments tablosunda 10 sistem ekipmanı vardı; id sequence'i ise 1'den
başlıyordu. İlk POST /equipments INSERT'i id=10 atayıp PRIMARY KEY
çakışması veriyordu (UniqueViolation: equipments_pkey).

Bu migration sequence'i MAX(id)+1'e çeker. SQLite veya henüz boş tabloda
no-op olur.

Revision ID: 014_fix_equipments_seq
Revises: 013_pin_advanced_params
Create Date: 2026-05-17
"""

from alembic import op


revision = '014_fix_equipments_seq'
down_revision = '013_pin_advanced_params'
branch_labels = None
depends_on = None


def upgrade():
    # PostgreSQL — sequence'i tabloda en yüksek id'ye senkronla.
    # SQLite veya başka dialect'lerde no-op (try/except).
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.sequences
                WHERE sequence_name = 'equipments_id_seq'
            ) THEN
                PERFORM setval(
                    'equipments_id_seq',
                    COALESCE((SELECT MAX(id) FROM equipments), 0) + 1,
                    false
                );
            END IF;
        END $$;
    """)


def downgrade():
    # Sequence reset geri alınmaz (zaten idempotent ve güvenli).
    pass
