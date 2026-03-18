"""
check_coverage.py
==================
Tum shard SQLite DB dosyalarini okur, hangi sehirlerin
hangi gorevlerinin tamamlandigini raporlar ve eksikleri
yeni manifest dosyalari olarak dagitir.

Calistirma:
  python check_coverage.py srrp_cihaz_1.db srrp_cihaz_2.db ...

  -- Ek olarak gap manifest uret (2 bilgisayara esit dagit):
  python check_coverage.py *.db --distribute 2

Cikti:
  - Konsol raporu (il/ilce bazli coverage)
  - gap_cihaz_1.json, gap_cihaz_2.json  (--distribute varsa)
"""

import sys
import json
import sqlite3
import argparse
from pathlib import Path
from datetime import date
from collections import defaultdict

if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Tam gorev seti: 9 yillik gunluk (2026 devam ettigi icin sayilmaz)
DAILY_YEARS  = list(range(2016, 2025))
HOURLY_YEARS = [2025]        # 2026 devam ediyor, bitmis sayilmaz
FINAL_TASKS  = (
    [f"daily_{y}"  for y in DAILY_YEARS]
    + [f"hourly_{y}" for y in HOURLY_YEARS]
)  # 10 gorev / sehir


def parse_args():
    p = argparse.ArgumentParser(description="SRRP Coverage Checker")
    p.add_argument("dbs", nargs="+", help="SQLite shard dosyalari")
    p.add_argument(
        "--distribute", type=int, default=0, metavar="N",
        help="Eksikleri N bilgisayara dagit, gap manifest olustur"
    )
    p.add_argument(
        "--prefix", default="gap_cihaz",
        help="Gap manifest dosya adi oneki (varsayilan: gap_cihaz)"
    )
    return p.parse_args()


def load_cities():
    json_path = Path(__file__).parent / "turkey_districts.json"
    if json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            return json.load(f)
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from app.core.constants import TURKEY_CITIES
        return TURKEY_CITIES
    except ImportError:
        print("HATA: Sehir listesi bulunamadi.")
        sys.exit(1)


def collect_done_tasks(db_paths):
    """
    Tum shard DB'lerinden tamamlanmis (lat, lon, task) set'ini topla.
    Donulus: {(lat, lon): set_of_done_tasks}
    """
    done = defaultdict(set)
    for db_path in db_paths:
        if not Path(db_path).exists():
            print(f"  [UYARI] Dosya yok: {db_path}")
            continue
        try:
            conn = sqlite3.connect(db_path)
            rows = conn.execute(
                "SELECT latitude, longitude, task FROM progress WHERE status='done'"
            ).fetchall()
            conn.close()
            for lat, lon, task in rows:
                done[(round(lat, 4), round(lon, 4))].add(task)
            print(f"  {db_path}: {len(rows):,} tamamlanmis gorev okundu")
        except Exception as e:
            print(f"  [HATA] {db_path}: {e}")
    return done


def main():
    args = parse_args()

    print("=" * 65)
    print("SRRP Coverage Kontrolu")
    print("=" * 65)

    # Sehir listesi
    cities = load_cities()
    total_cities = len(cities)
    total_tasks  = total_cities * len(FINAL_TASKS)

    print(f"\nSehir: {total_cities}  |  Gorev/sehir: {len(FINAL_TASKS)}  |  Toplam: {total_tasks:,}")
    print(f"Gorevler: {FINAL_TASKS[0]} ... {FINAL_TASKS[-1]}\n")

    # Tum DB'leri tara
    done = collect_done_tasks(args.dbs)

    # --- Coverage analizi ---
    missing_cities = []   # Her eksik sehir icin {city, missing_tasks}
    done_count     = 0
    full_count     = 0   # Tum gorevleri tamam olan sehir sayisi

    # Il bazli ozet
    province_stats = defaultdict(lambda: {"total": 0, "done": 0})

    for city in cities:
        lat = round(city["lat"], 4)
        lon = round(city["lon"], 4)
        key = (lat, lon)

        city_done    = done.get(key, set())
        missing      = [t for t in FINAL_TASKS if t not in city_done]
        city_done_n  = len(FINAL_TASKS) - len(missing)

        done_count += city_done_n
        province_stats[city["province"]]["total"] += len(FINAL_TASKS)
        province_stats[city["province"]]["done"]  += city_done_n

        if not missing:
            full_count += 1
        else:
            missing_cities.append({**city, "only_tasks": missing})

    missing_count = total_tasks - done_count
    coverage_pct  = 100 * done_count / total_tasks if total_tasks else 0

    # --- Ozet rapor ---
    print("\n" + "=" * 65)
    print(f"  GENEL COVERAGE: {coverage_pct:.1f}%")
    print(f"  Tamamlanan gorev  : {done_count:,} / {total_tasks:,}")
    print(f"  Eksik gorev       : {missing_count:,}")
    print(f"  Tam biten sehir   : {full_count} / {total_cities}")
    print(f"  Eksik olan sehir  : {len(missing_cities)}")
    print("=" * 65)

    # --- Il bazli ozet (eksik olanlar) ---
    low_coverage = {
        il: s for il, s in province_stats.items()
        if s["done"] < s["total"]
    }
    if low_coverage:
        print(f"\nEksik olan iller ({len(low_coverage)}):\n")
        for il, s in sorted(low_coverage.items(), key=lambda x: x[1]["done"] / x[1]["total"]):
            pct   = 100 * s["done"] / s["total"]
            eksik = s["total"] - s["done"]
            bar   = "#" * int(pct / 5) + "." * (20 - int(pct / 5))
            print(f"  {il:<20} [{bar}] {pct:5.1f}%  ({eksik} eksik gorev)")

    if not missing_cities:
        print("\nTum veriler tamam! Merge icin hazir.")
        return

    # --- Gap manifest olustur ---
    if args.distribute > 0:
        n = args.distribute
        print(f"\nEksik {len(missing_cities)} sehir, {n} bilgisayara dagitiliyor...")

        # Round-robin dagit
        shards = [[] for _ in range(n)]
        for i, city in enumerate(missing_cities):
            shards[i % n].append(city)

        today = date.today().isoformat()
        for idx, shard in enumerate(shards, 1):
            if not shard:
                continue
            filename = f"{args.prefix}_{idx}.json"
            manifest = {
                "id":      f"gap_cihaz_{idx}",
                "created": today,
                "mode":    "gap_fill",
                "total":   len(shard),
                "cities":  shard,
            }
            with open(filename, "w", encoding="utf-8") as f:
                json.dump(manifest, f, ensure_ascii=False, indent=2)

            # Eksik gorev sayisi
            task_count = sum(len(c["only_tasks"]) for c in shard)
            print(f"  {filename}  — {len(shard)} sehir, {task_count:,} gorev")

        print(f"\nGap manifest'ler olusturuldu.")
        print("Simdi yapilacaklar:")
        for i in range(1, n + 1):
            print(f"  Cihaz {i}: gap_cihaz_{i}.json gonder")
        print("  Calistirilacak: python srrp_backfill.py --manifest gap_cihaz_X.json")
    else:
        print(f"\nGap manifest olusturmak icin: --distribute N")
        print("Ornek: python check_coverage.py *.db --distribute 4")

    print("=" * 65)


if __name__ == "__main__":
    main()
