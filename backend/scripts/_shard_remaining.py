"""Belirli shard için ÇEKİLMEMİŞ ilçe sayısını yazar (loop break kontrolü).

Kullanım: python _shard_remaining.py <shard> <of> <csv_path>
districts.csv ile aynı dizinde çalıştırılmalı.
"""
import csv
import sys

sh, of, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
alld = list(csv.DictReader(open("districts.csv", encoding="utf-8")))
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
