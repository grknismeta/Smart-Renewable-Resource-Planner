"""Shard CSV'lerini tek dosyada birleştirir; (il,ilçe,tarih) mükerrerini ayıklar.

Dağıtık fetch (fetch_district_weather.py --shard i --of N) çıktılarını prod'a
COPY'den önce birleştirmek için. Tek başlık + dedup garantisi.

Kullanım:
    python merge_weather_csvs.py weather_district.csv w0.csv w_srv.csv [...]
"""
import csv
import sys

OUT_COLS = [
    "latitude", "longitude", "date", "province_name", "district_name",
    "shortwave_radiation_sum", "wind_speed_mean", "wind_speed_max",
    "wind_direction_dominant", "temperature_mean", "precipitation_sum",
    "cloud_cover_mean", "relative_humidity_mean",
]

if len(sys.argv) < 3:
    print("Kullanım: python merge_weather_csvs.py <çıktı.csv> <girdi1.csv> [girdi2.csv ...]")
    sys.exit(1)

out_path = sys.argv[1]
in_paths = sys.argv[2:]
seen = set()
written = 0
dup = 0
districts = set()

with open(out_path, "w", encoding="utf-8", newline="") as fo:
    w = csv.writer(fo)
    w.writerow(OUT_COLS)
    for path in in_paths:
        rows_this = 0
        try:
            with open(path, encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    key = (r.get("province_name"), r.get("district_name"), r.get("date"))
                    if key in seen:
                        dup += 1
                        continue
                    seen.add(key)
                    districts.add((r.get("province_name"), r.get("district_name")))
                    w.writerow([r.get(c, "") for c in OUT_COLS])
                    written += 1
                    rows_this += 1
            print(f"  {path}: {rows_this} satır")
        except FileNotFoundError:
            print(f"  ! {path} bulunamadı — atlandı")

print(f"\nBİTTİ → {out_path}: {written} satır, {len(districts)} ilçe "
      f"({dup} mükerrer atlandı)")
