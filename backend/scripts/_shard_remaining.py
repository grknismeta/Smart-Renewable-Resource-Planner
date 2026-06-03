"""Belirli shard için ÇEKİLMEMİŞ ilçe sayısını yazar (loop break kontrolü).

Kullanım: python _shard_remaining.py <shard> <of> <csv_path> [districts_csv]
districts_csv verilmezse cwd'deki 'districts.csv' kullanılır.
"""
import csv
import sys

sh, of, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
districts_path = sys.argv[4] if len(sys.argv) > 4 else "districts.csv"
alld = list(csv.DictReader(open(districts_path, encoding="utf-8")))
mine = {
    (d["province"].strip(), d["district"].strip())
    for i, d in enumerate(alld)
    if i % of == sh
}
done = set()
try:
    for r in csv.DictReader(open(path, encoding="utf-8")):
        done.add((
            (r.get("province_name") or "").strip(),
            (r.get("district_name") or "").strip(),
        ))
except FileNotFoundError:
    pass
print(len(mine - done))
