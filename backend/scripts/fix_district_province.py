"""
Sprint 4 — İlçe/İl Eşleştirme Düzeltme Scripti
================================================

Sorun:
  Overpass API bounding box sorguları bazı ilçeleri yanlış ile atıyor.
  Örnek: Antakya → "Adana" kaydedilmiş, "Hatay" olmalı.

Çözüm:
  constants.py içindeki TURKEY_CITIES verisi koordinat ve province alanları
  ile her ilçe için doğru il atamasını içeriyor. Bu script:
  1. HourlyWeatherData'daki (district_name IS NOT NULL) tüm kayıtları tarar.
  2. Her (district_name, city_name) çiftini TURKEY_CITIES ile karşılaştırır.
  3. city_name yanlışsa doğru province değeriyle günceller.

Kullanım:
  python scripts/fix_district_province.py [--dry-run] [--province <il>]

  --dry-run    : Değişiklikleri göster, DB'ye yazma
  --province X : Sadece belirli bir il kaydını düzelt

Güvenli:
  - Her düzeltme öncesinde mevcut değer loglanır.
  - İşlem sonunda toplam güncelleme sayısı rapor edilir.
  - Dry-run modunda hiçbir şey değişmez.
"""

import sys
import logging
import argparse
from collections import defaultdict

# Backend root'unu sys.path'e ekle
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from app.core.constants import TURKEY_CITIES

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


def build_correction_map() -> dict:
    """
    TURKEY_CITIES'den doğru il atamasını içeren lookup tablosu oluşturur.
    Dönüş: { district_name_lower: correct_province }

    Önemli: Birden fazla ilde aynı isimde ilçe varsa (örn. "Merkez"),
    bu ilçe için koordinat tabanlı eşleştirme gerekir — basit isim eşleşmesi
    hatalı sonuç verebilir. Bu durumlar AMBIGUOUS_DISTRICTS setinde işaretlenir.
    """
    district_to_province: dict = {}
    ambiguous: set = set()

    for city in TURKEY_CITIES:
        district = city.get("district")
        if district is None:
            continue  # il merkezi (district=None), atla
        province = city["province"]
        key = district.strip().lower()

        if key in district_to_province:
            existing = district_to_province[key]
            if existing != province:
                ambiguous.add(key)
        else:
            district_to_province[key] = province

    if ambiguous:
        logger.warning(
            f"{len(ambiguous)} ambiguous ilçe ismi (birden fazla ilde var): "
            f"{sorted(list(ambiguous))[:10]}{'...' if len(ambiguous) > 10 else ''}"
        )
        logger.warning("Bu ilçeler için isim tabanlı düzeltme yapılmaz (koordinat gerekir).")

    # Ambiguous ilçeleri haritadan çıkar
    for key in ambiguous:
        district_to_province.pop(key, None)

    logger.info(f"Düzeltme haritası hazır: {len(district_to_province)} benzersiz ilçe")
    return district_to_province, ambiguous


def run_fix(dry_run: bool = False, filter_province: str | None = None):
    """Ana düzeltme fonksiyonu."""
    correction_map, ambiguous = build_correction_map()

    db = SystemSessionLocal()
    try:
        # Tüm (city_name, district_name) çiftlerini çek
        query = db.query(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
        ).filter(
            HourlyWeatherData.district_name.isnot(None),
        ).distinct()

        if filter_province:
            query = query.filter(
                HourlyWeatherData.city_name.ilike(f"%{filter_province}%")
            )

        pairs = query.all()
        logger.info(f"Toplam {len(pairs)} benzersiz (il, ilçe) çifti kontrol edilecek")

        corrections_needed: list = []
        skipped_ambiguous: int = 0

        for city_name, district_name in pairs:
            if not district_name or not city_name:
                continue

            district_lower = district_name.strip().lower()

            # Ambiguous ilçeyi atla
            if district_lower in ambiguous:
                skipped_ambiguous += 1
                continue

            correct_province = correction_map.get(district_lower)
            if correct_province is None:
                # constants.py'de bu ilçe yok — veri kalitesi sorunu, atla
                logger.debug(f"  Bilinmeyen ilçe: '{district_name}' → atlandı")
                continue

            # İl adı farklı mı?
            if city_name.strip().lower() != correct_province.strip().lower():
                corrections_needed.append((city_name, district_name, correct_province))

        logger.info(
            f"Düzeltme gerekiyor: {len(corrections_needed)} çift | "
            f"Ambiguous atlandı: {skipped_ambiguous}"
        )

        if not corrections_needed:
            logger.info("✅ Düzeltme gerekmiyor, veri tutarlı.")
            return

        # Düzeltmeleri göster
        for wrong_province, district_name, correct_province in corrections_needed:
            logger.info(
                f"  DÜZELT: district='{district_name}' | "
                f"city_name '{wrong_province}' → '{correct_province}'"
            )

        if dry_run:
            logger.info(f"\n🔍 DRY-RUN — {len(corrections_needed)} düzeltme yapılacaktı (hiçbir şey değişmedi)")
            return

        # DB güncellemeleri
        total_updated = 0
        for wrong_province, district_name, correct_province in corrections_needed:
            updated_count = db.query(HourlyWeatherData).filter(
                HourlyWeatherData.city_name == wrong_province,
                HourlyWeatherData.district_name == district_name,
            ).update(
                {HourlyWeatherData.city_name: correct_province},
                synchronize_session=False,
            )
            total_updated += updated_count
            logger.info(
                f"  ✓ '{district_name}': {updated_count} satır güncellendi "
                f"({wrong_province} → {correct_province})"
            )

        db.commit()
        logger.info(f"\n✅ Tamamlandı. Toplam {total_updated} satır güncellendi.")

    except Exception as e:
        db.rollback()
        logger.error(f"Hata: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="HourlyWeatherData'da yanlış il ataması olan ilçeleri düzeltir."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Değişiklikleri göster ama DB'ye yazma",
    )
    parser.add_argument(
        "--province",
        type=str,
        default=None,
        help="Sadece bu ildeki kayıtları kontrol et (ör: Adana)",
    )
    args = parser.parse_args()

    logger.info(f"{'[DRY-RUN] ' if args.dry_run else ''}İlçe-İl eşleştirme düzeltmesi başlıyor...")
    run_fix(dry_run=args.dry_run, filter_province=args.province)
