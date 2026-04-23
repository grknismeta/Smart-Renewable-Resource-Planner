"""Gecici tani script - Isinim choropleth dogu-bati asimetrisi kok sebep analizi.

Calistir: backend/ icinden `python scripts/diag_east_west.py`
"""
from __future__ import annotations

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Windows cp1254 console encoding'de ASCII-dışı karakterler patlar
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from datetime import datetime, timedelta
from collections import Counter

from sqlalchemy import func, and_
from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData


def main() -> None:
    db = SystemSessionLocal()
    try:
        # 1) DB'de kaç farklı ilçe var?
        total_districts = db.query(
            func.count(func.distinct(
                func.concat(HourlyWeatherData.city_name, '|', HourlyWeatherData.district_name)
            ))
        ).filter(HourlyWeatherData.district_name.isnot(None)).scalar()
        print(f"[1] Toplam distinct (city,district): {total_districts}")

        # 2) Her ilçenin MAX(timestamp) → en eski/en yeni ilçe
        subq = (
            db.query(
                HourlyWeatherData.city_name.label("c"),
                HourlyWeatherData.district_name.label("d"),
                func.max(HourlyWeatherData.timestamp).label("max_ts"),
                func.avg(HourlyWeatherData.longitude).label("avg_lon"),
            )
            .filter(HourlyWeatherData.district_name.isnot(None))
            .group_by(HourlyWeatherData.city_name, HourlyWeatherData.district_name)
            .subquery()
        )
        rows = db.query(subq).all()
        max_list = [(r.c, r.d, r.max_ts, r.avg_lon) for r in rows]
        max_list.sort(key=lambda x: x[2])
        print(f"\n[2] Per-district MAX(timestamp):")
        print(f"  En eski 5:")
        for r in max_list[:5]:
            print(f"    {r[2]} — {r[0]}/{r[1]} (lon={r[3]:.2f})")
        print(f"  En yeni 5:")
        for r in max_list[-5:]:
            print(f"    {r[2]} — {r[0]}/{r[1]} (lon={r[3]:.2f})")

        # 3) Timestamp dağılımı — saat bazında
        ts_histogram = Counter(r[2] for r in max_list)
        print(f"\n[3] max_ts histogram (top 10):")
        for ts, count in ts_histogram.most_common(10):
            print(f"    {ts}: {count} ilçe")

        # 4) Doğu-batı analizi — her ilçeyi longitude'a göre ayır
        west = [r for r in max_list if r[3] < 35.0]   # ~Ankara batısı
        east = [r for r in max_list if r[3] >= 35.0]
        print(f"\n[4] Longitude split (35E cutoff):")
        print(f"  Bati (<35): {len(west)} ilce")
        print(f"  Dogu (>=35): {len(east)} ilce")
        if west:
            print(f"  Batı max_ts min/max: {min(r[2] for r in west)} → {max(r[2] for r in west)}")
        if east:
            print(f"  Doğu max_ts min/max: {min(r[2] for r in east)} → {max(r[2] for r in east)}")

        # 5) Her ilçenin EN SON saatteki shortwave_radiation değeri
        # Join per-district latest ts → row
        latest_rows = (
            db.query(
                HourlyWeatherData.city_name,
                HourlyWeatherData.district_name,
                HourlyWeatherData.shortwave_radiation,
                HourlyWeatherData.longitude,
                HourlyWeatherData.timestamp,
            )
            .join(
                subq,
                and_(
                    HourlyWeatherData.city_name == subq.c.c,
                    HourlyWeatherData.district_name == subq.c.d,
                    HourlyWeatherData.timestamp == subq.c.max_ts,
                ),
            )
            .all()
        )
        print(f"\n[5] Latest radiation join: {len(latest_rows)} satır döndü")
        west_rad = [r.shortwave_radiation for r in latest_rows if r.longitude < 35 and r.shortwave_radiation is not None]
        east_rad = [r.shortwave_radiation for r in latest_rows if r.longitude >= 35 and r.shortwave_radiation is not None]
        if west_rad:
            print(f"  Bati radiation: n={len(west_rad)}, avg={sum(west_rad)/len(west_rad):.1f}, "
                  f"min={min(west_rad):.1f}, max={max(west_rad):.1f}, "
                  f"zero_count={sum(1 for v in west_rad if v==0)}")
        if east_rad:
            print(f"  Dogu radiation: n={len(east_rad)}, avg={sum(east_rad)/len(east_rad):.1f}, "
                  f"min={min(east_rad):.1f}, max={max(east_rad):.1f}, "
                  f"zero_count={sum(1 for v in east_rad if v==0)}")

        # 6) Solar subquery (radiation > 0) — her ilçenin en son gündüz saati
        solar_subq = (
            db.query(
                HourlyWeatherData.city_name.label("c"),
                HourlyWeatherData.district_name.label("d"),
                func.max(HourlyWeatherData.timestamp).label("max_ts"),
            )
            .filter(
                HourlyWeatherData.district_name.isnot(None),
                HourlyWeatherData.shortwave_radiation > 0,
            )
            .group_by(HourlyWeatherData.city_name, HourlyWeatherData.district_name)
            .subquery()
        )
        solar_rows = (
            db.query(
                HourlyWeatherData.city_name,
                HourlyWeatherData.district_name,
                HourlyWeatherData.shortwave_radiation,
                HourlyWeatherData.longitude,
                HourlyWeatherData.timestamp,
            )
            .join(
                solar_subq,
                and_(
                    HourlyWeatherData.city_name == solar_subq.c.c,
                    HourlyWeatherData.district_name == solar_subq.c.d,
                    HourlyWeatherData.timestamp == solar_subq.c.max_ts,
                ),
            )
            .all()
        )
        print(f"\n[6] Solar (radiation>0) subquery: {len(solar_rows)} satır")
        west_solar = [(r.shortwave_radiation, r.timestamp) for r in solar_rows if r.longitude < 35]
        east_solar = [(r.shortwave_radiation, r.timestamp) for r in solar_rows if r.longitude >= 35]
        if west_solar:
            rads = [x[0] for x in west_solar]
            tss = [x[1] for x in west_solar]
            print(f"  Bati: n={len(west_solar)}, rad avg={sum(rads)/len(rads):.1f}, "
                  f"ts range {min(tss)} -> {max(tss)}")
        if east_solar:
            rads = [x[0] for x in east_solar]
            tss = [x[1] for x in east_solar]
            print(f"  Dogu: n={len(east_solar)}, rad avg={sum(rads)/len(rads):.1f}, "
                  f"ts range {min(tss)} -> {max(tss)}")

        # 7) Global timestamp bilgisi
        global_max = db.query(func.max(HourlyWeatherData.timestamp)).filter(
            HourlyWeatherData.district_name.isnot(None)
        ).scalar()
        global_min = db.query(func.min(HourlyWeatherData.timestamp)).filter(
            HourlyWeatherData.district_name.isnot(None)
        ).scalar()
        print(f"\n[7] Global range: {global_min} -> {global_max}")
        print(f"    Su an: {datetime.utcnow()} UTC / {datetime.now()} local")

        # 8) Fetch tazeliği — 24 saatten yeni kaydı olan ilçe sayısı
        cutoff = datetime.utcnow() - timedelta(hours=24)
        fresh = (
            db.query(
                func.count(func.distinct(
                    func.concat(HourlyWeatherData.city_name, '|', HourlyWeatherData.district_name)
                ))
            )
            .filter(
                HourlyWeatherData.district_name.isnot(None),
                HourlyWeatherData.timestamp >= cutoff,
            )
            .scalar()
        )
        print(f"\n[8] Son 24 saatte kaydi olan ilce: {fresh}/{total_districts}")

        # 9) Örnek — İstanbul/Şişli vs. Van/İpekyolu son saatlerde ne var?
        for city, dist in [("İstanbul", "Şişli"), ("Van", "İpekyolu"), ("Ankara", "Çankaya"), ("Erzurum", "Yakutiye"), ("İzmir", "Bornova")]:
            row = (
                db.query(HourlyWeatherData.timestamp, HourlyWeatherData.shortwave_radiation)
                .filter(
                    HourlyWeatherData.city_name == city,
                    HourlyWeatherData.district_name == dist,
                )
                .order_by(HourlyWeatherData.timestamp.desc())
                .first()
            )
            if row:
                print(f"  {city}/{dist}: latest_ts={row.timestamp} rad={row.shortwave_radiation}")
            else:
                print(f"  {city}/{dist}: KAYIT YOK")

        # 10) Örnek 20 ilçe için TEKİL radiation histogramı — son 24 saat içindeki tüm daylight saatleri
        print(f"\n[10] Son 48 saatteki radiation > 0 kayit sayisi (ornek):")
        cutoff48 = datetime.utcnow() - timedelta(hours=48)
        for city, dist in [("Istanbul", "Sisli"), ("Van", "Ipekyolu"), ("Ankara", "Cankaya"),
                            ("Izmir", "Bornova"), ("Antalya", "Muratpasa"),
                            ("Diyarbakir", "Kayapinar"), ("Erzurum", "Yakutiye")]:
            cnt = (
                db.query(func.count(HourlyWeatherData.id))
                .filter(
                    HourlyWeatherData.city_name == city,
                    HourlyWeatherData.district_name == dist,
                    HourlyWeatherData.timestamp >= cutoff48,
                    HourlyWeatherData.shortwave_radiation > 0,
                )
                .scalar()
            )
            max_rad = (
                db.query(func.max(HourlyWeatherData.shortwave_radiation))
                .filter(
                    HourlyWeatherData.city_name == city,
                    HourlyWeatherData.district_name == dist,
                    HourlyWeatherData.timestamp >= cutoff48,
                )
                .scalar()
            )
            print(f"  {city}/{dist}: {cnt} daylight saat, max_rad_48h={max_rad}")

    finally:
        db.close()


if __name__ == "__main__":
    main()
