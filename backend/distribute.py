"""
distribute.py
==============
Tam sehir listesini N bilgisayara esit olarak boler,
her biri icin manifest dosyasi olusturur.

Calistirma:
  python distribute.py              -> 4 cihaz (varsayilan)
  python distribute.py --computers 3

Cikti:
  manifest_cihaz_1.json  (264 sehir)
  manifest_cihaz_2.json  (264 sehir)
  manifest_cihaz_3.json  (263 sehir)
  manifest_cihaz_4.json  (263 sehir)

Her manifest dosyasini ilgili bilgisayara gonder.
Backfill: python srrp_backfill.py --manifest manifest_cihaz_1.json
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import date

# Windows encoding
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def load_cities():
    json_path = Path(__file__).parent / "turkey_districts.json"
    if json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            cities = json.load(f)
        print(f"Sehir listesi: turkey_districts.json — {len(cities)} konum")
        return cities

    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from app.core.constants import TURKEY_CITIES
        print(f"Sehir listesi: app.core.constants — {len(TURKEY_CITIES)} konum")
        return TURKEY_CITIES
    except ImportError:
        print("HATA: turkey_districts.json veya app/core/constants.py bulunamadi!")
        print("  Once calistirin: python generate_turkey_districts_overpass.py")
        sys.exit(1)


def parse_args():
    p = argparse.ArgumentParser(description="SRRP Is Dagitici")
    p.add_argument(
        "--computers", type=int, default=4,
        help="Kac bilgisayara bolunecek (varsayilan: 4)"
    )
    p.add_argument(
        "--prefix", default="manifest_cihaz",
        help="Cikti dosya adi oneki (varsayilan: manifest_cihaz)"
    )
    return p.parse_args()


def main():
    args  = parse_args()
    n     = args.computers
    cities = load_cities()
    today  = date.today().isoformat()

    print(f"\n{len(cities)} sehir, {n} bilgisayara bolunuyor...\n")

    # Her sehiri round-robin dagit: sehir i -> bilgisayar (i % n)
    shards = [[] for _ in range(n)]
    for i, city in enumerate(cities):
        shards[i % n].append(city)

    for idx, shard in enumerate(shards, 1):
        filename = f"{args.prefix}_{idx}.json"
        manifest = {
            "id":       f"cihaz_{idx}",
            "created":  today,
            "total":    len(shard),
            "computers": n,
            "cities":   shard,
        }
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=True, indent=2)
        print(f"  {filename}  — {len(shard)} sehir")

    print(f"\nTamamlandi! {n} manifest dosyasi olusturuldu.")
    print("Simdi yapilacaklar:")
    for i in range(1, n + 1):
        print(f"  Cihaz {i}: manifest_cihaz_{i}.json + srrp_backfill.py gonder")
    print(f"  Calistirilacak komut: python srrp_backfill.py --manifest manifest_cihaz_X.json")


if __name__ == "__main__":
    main()
