"""APScheduler — Saatlik veri scheduler'ı (Faz 1).

Vault prensibi (PROJECT-OVERVIEW #2):
    "APScheduler, 24/gün Open-Meteo çekimi."

Bu modül:
  1. `BackgroundScheduler` + `CronTrigger(minute=0)` ile her saatin 0. dakikasında
     Open-Meteo'dan 81 il için hourly çekim yapar (mevcut `update_hourly_data`).
  2. Çekim sonrası `province_analysis` tablosunu günceller (analysis_service).
  3. Her iş için `scheduler_meta` tablosuna `last_run_at`, `status`, `duration`
     yazar — `/system/status` endpoint'i buradan okur ("228 dk önce" fix).

main.py lifespan'ı `start_scheduler()`'ı startup'ta, `shutdown_scheduler()`'ı
kapanışta çağırır. Eski `_periodic_hourly_update` asyncio loop'u kaldırılır.
"""

from __future__ import annotations

import time
import logging
from datetime import datetime, timezone
from typing import Callable, Optional

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.exc import SQLAlchemyError

from ..db.database import SystemSessionLocal
from ..db.models import SchedulerMeta

logger = logging.getLogger(__name__)

# Job adları (scheduler_meta.job_name'de tekil olarak tutulur)
JOB_HOURLY_FETCH = "hourly_weather_fetch"
JOB_PROVINCE_ANALYSIS = "province_analysis_recompute"  # legacy (deprecated S1)
JOB_CLIMATOLOGY_REFRESH = "climatology_refresh"  # 2026-05-17 S1.10: 6 ayda bir
JOB_THEMATIC_AGGREGATE = "thematic_aggregate_refresh"  # 2026-05-28: ayda bir

_scheduler: Optional[BackgroundScheduler] = None


# ───────────────────── Tematik agregat refresh (ayda bir) ─────────────────

def _thematic_aggregate_refresh() -> None:
    """Ağır tematik pencereleri (6ay/yıl/mevsim/2y/5y/10y) ayda bir hesapla.

    `build_thematic_aggregates.main` çağırır → thematic_aggregate tablosu.
    İl + ilçe, hibrit kaynak (yakın saatlik, eski günlük). ~1-2 dk.
    """
    logger.info("[Scheduler] thematic_aggregate_refresh BAŞLADI")
    try:
        import sys
        import os
        # scripts/ paketini import path'e ekle
        scripts_dir = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "scripts")
        )
        if scripts_dir not in sys.path:
            sys.path.insert(0, scripts_dir)
        import build_thematic_aggregates as bta  # type: ignore
        bta.main(only_province=False, dry_run=False)
        # T-6: zaman-serisi frame'leri (2y/5y/10y haftalık/aylık)
        import build_thematic_timeseries as bts  # type: ignore
        bts.main(years=10, dry_run=False)
        logger.info("[Scheduler] thematic_aggregate_refresh BİTTİ")
    except Exception:
        logger.exception("[Scheduler] thematic_aggregate_refresh hatası")
        raise


# ───────────────────────── S1.10: Climatology refresh job ─────────────────

def _climatology_refresh() -> None:
    """6 ayda bir climatology tablosunu yeniden hesapla.

    Sprint S1 — `compute_for_all_provinces` çağırır. Manisa örneği:
    skor sürekli recompute edilmez (bölge karakteri statik), ama uzun vade
    değişimlerini (yeni veri toplandıkça mevsim ortalamaları değişir)
    yansıtmak için 6 ayda bir refresh.

    Çalışma süresi ~5-10 dk (162 hesap × ~3-5sn). BackgroundScheduler
    arka planda çalıştırır, FastAPI request handling'i bloklamaz.
    """
    from .climatology_service import compute_for_all_provinces

    logger.info("[Scheduler] climatology_refresh BAŞLADI")
    try:
        results = compute_for_all_provinces(
            resource_types=("wind", "solar"),
            save=True,
        )
        ok_count = sum(1 for r in results if r.score_climatology is not None)
        logger.info(
            "[Scheduler] climatology_refresh BİTTİ: %d/%d skor üretildi",
            ok_count, len(results),
        )
    except Exception:
        logger.exception("[Scheduler] climatology_refresh hatası")
        raise


# ───────────────────────── Meta helpers ─────────────────────────

def _mark_run_start(job_name: str) -> None:
    """Job başlarken scheduler_meta'ya `running` status yazar."""
    db = SystemSessionLocal()
    try:
        row = db.query(SchedulerMeta).filter(SchedulerMeta.job_name == job_name).first()
        if row is None:
            row = SchedulerMeta(job_name=job_name, run_count=0)
            db.add(row)
        row.last_status = "running"
        row.last_error = None
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        logger.exception("scheduler_meta start kaydi basarisiz: %s", job_name)
    finally:
        db.close()


def _mark_run_end(
    job_name: str,
    status: str,
    duration_seconds: float,
    error: Optional[str] = None,
    next_run_at: Optional[datetime] = None,
) -> None:
    """Job bitiminde (ok/fail) son çalışma bilgilerini yazar."""
    db = SystemSessionLocal()
    try:
        row = db.query(SchedulerMeta).filter(SchedulerMeta.job_name == job_name).first()
        if row is None:
            row = SchedulerMeta(job_name=job_name, run_count=0)
            db.add(row)
        row.last_run_at = datetime.now(timezone.utc)
        row.last_status = status
        row.last_duration_seconds = float(duration_seconds)
        row.last_error = (error or None) if status != "ok" else None
        row.run_count = (row.run_count or 0) + 1
        if next_run_at is not None:
            row.next_run_at = next_run_at
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        logger.exception("scheduler_meta end kaydi basarisiz: %s", job_name)
    finally:
        db.close()


def _job_next_run_at(job_id: str) -> Optional[datetime]:
    """Scheduler'dan bir işin sonraki tetikleme zamanını alır."""
    if _scheduler is None:
        return None
    job = _scheduler.get_job(job_id)
    if job is None or job.next_run_time is None:
        return None
    # APScheduler tz-aware datetime döner
    return job.next_run_time


# ───────────────────────── Job wrapper ─────────────────────────

def _run_tracked(job_name: str, fn: Callable[[], None]) -> None:
    """Job'ı çalıştırır; süre + status + hata'yı scheduler_meta'ya yazar."""
    _mark_run_start(job_name)
    t0 = time.monotonic()
    try:
        fn()
        dur = time.monotonic() - t0
        _mark_run_end(
            job_name,
            status="ok",
            duration_seconds=dur,
            next_run_at=_job_next_run_at(job_name),
        )
        logger.info("scheduler job '%s' OK (%.1fs)", job_name, dur)
    except Exception as exc:  # noqa: BLE001
        dur = time.monotonic() - t0
        _mark_run_end(
            job_name,
            status="fail",
            duration_seconds=dur,
            error=f"{type(exc).__name__}: {exc}",
            next_run_at=_job_next_run_at(job_name),
        )
        logger.exception("scheduler job '%s' FAIL (%.1fs)", job_name, dur)


# ───────────────────────── Job bodies ─────────────────────────

def _hourly_fetch_and_recompute() -> None:
    """
    1) Open-Meteo hourly fetch (81 il)
    2) province_analysis recompute (tek kaynak tablosu)

    Her iki adımın başlangıç/bitiş zamanı log'a yazılır — geç tetikleme veya
    yavaş çalışma durumunda timestamp'lerden teşhis kolaylaştırılır.
    """
    # Geç import — circular import ve startup sırasını kırar
    from .collectors.hourly import update_hourly_data
    from . import analysis_service

    logger.info("[scheduler] hourly fetch BAŞLADI")
    t0 = time.monotonic()
    update_hourly_data()
    logger.info("[scheduler] hourly fetch bitti (%.1fs)", time.monotonic() - t0)

    logger.info("[scheduler] province_analysis recompute BAŞLADI")
    t1 = time.monotonic()
    analysis_service.recompute_all_provinces()
    logger.info(
        "[scheduler] province_analysis recompute bitti (%.1fs)",
        time.monotonic() - t1,
    )


# ───────────────────────── Public API ─────────────────────────

def start_scheduler(run_on_startup: bool = True) -> BackgroundScheduler:
    """
    APScheduler'ı başlatır ve saatlik işi kaydeder.

    Args:
        run_on_startup: True ise uygulama açılışında bir kez hemen çalıştırır
                        (mevcut davranışla uyumlu — ilk açılışta veri güncel olsun).
    """
    global _scheduler
    if _scheduler is not None and _scheduler.running:
        logger.warning("Scheduler zaten calisiyor.")
        return _scheduler

    _scheduler = BackgroundScheduler(timezone="UTC")

    _scheduler.add_job(
        func=lambda: _run_tracked(JOB_HOURLY_FETCH, _hourly_fetch_and_recompute),
        trigger=CronTrigger(minute=0),  # her saatin 0. dakikası
        id=JOB_HOURLY_FETCH,
        name="Saatlik Open-Meteo cekim + province_analysis recompute",
        max_instances=1,
        coalesce=True,  # kaçan tetiklemeler tek seferde toparlanır
        misfire_grace_time=300,
        replace_existing=True,
    )

    # 2026-05-17 S1.10: Climatology 6 ayda bir refresh (Ocak ve Temmuz, ayın 1'i, 03:00 UTC)
    # Sebep: bölge karakteri statik ama mevsim ortalamaları zamanla değişir.
    # Manisa örneği — günlük/saatlik değil, 6 ayda bir.
    _scheduler.add_job(
        func=lambda: _run_tracked(JOB_CLIMATOLOGY_REFRESH, _climatology_refresh),
        trigger=CronTrigger(month="1,7", day=1, hour=3, minute=0),
        id=JOB_CLIMATOLOGY_REFRESH,
        name="6 ayda bir climatology recompute (81 il × 2 kaynak)",
        max_instances=1,
        coalesce=True,
        misfire_grace_time=3600,  # 1 saat geç bile çalışır (uzun job)
        replace_existing=True,
    )

    # 2026-05-28: Ağır tematik pencereler ayda bir (ayın 1'i, 04:00 UTC).
    # 6ay/yıl/mevsim/2y/5y/10y choropleth değerleri önceden hesaplanır.
    _scheduler.add_job(
        func=lambda: _run_tracked(JOB_THEMATIC_AGGREGATE,
                                  _thematic_aggregate_refresh),
        trigger=CronTrigger(day=1, hour=4, minute=0),
        id=JOB_THEMATIC_AGGREGATE,
        name="Ayda bir tematik agregat (il+ilçe × 6 pencere × 3 metrik)",
        max_instances=1,
        coalesce=True,
        misfire_grace_time=3600,
        replace_existing=True,
    )

    _scheduler.start()
    logger.info(
        "APScheduler baslatildi. Job'lar kayitli: %s, %s, %s",
        JOB_HOURLY_FETCH, JOB_CLIMATOLOGY_REFRESH, JOB_THEMATIC_AGGREGATE,
    )

    # next_run_at'i hemen kaydet (UI ilk anda da gostersin)
    _mark_run_end(
        JOB_HOURLY_FETCH,
        status=(
            _current_status(JOB_HOURLY_FETCH) or "pending"
        ),
        duration_seconds=0.0,
        next_run_at=_job_next_run_at(JOB_HOURLY_FETCH),
    )

    if run_on_startup:
        # İlk çalışma cron'u beklemesin — job'ı **şimdi** tetikle.
        # BackgroundScheduler arka planda çalıştırır, startup'ı bloklamaz.
        # `next_run_time` explicit verilmezse APScheduler trigger=None ile
        # implicit DateTrigger kullanıyor ama wakeup loop'una bağlı —
        # bazen dakikalarca gecikiyor. Explicit `now(UTC)` ile bu garanti.
        _scheduler.add_job(
            func=lambda: _run_tracked(JOB_HOURLY_FETCH, _hourly_fetch_and_recompute),
            trigger="date",
            run_date=datetime.now(timezone.utc),
            id=f"{JOB_HOURLY_FETCH}_startup",
            name="Startup'ta ilk calisma",
            max_instances=1,
            replace_existing=True,
        )
        logger.info(
            "Startup ilk fetch job kaydedildi (run_date=now). Saatlik cron ayrica devam edecek."
        )

    return _scheduler


def shutdown_scheduler(wait: bool = False) -> None:
    """FastAPI shutdown'ında çağrılır."""
    global _scheduler
    if _scheduler is None:
        return
    try:
        _scheduler.shutdown(wait=wait)
        logger.info("APScheduler kapatildi.")
    except Exception:
        logger.exception("Scheduler shutdown hatasi")
    finally:
        _scheduler = None


def get_scheduler() -> Optional[BackgroundScheduler]:
    return _scheduler


def _current_status(job_name: str) -> Optional[str]:
    """scheduler_meta'daki mevcut status'u (varsa) döner — UI için."""
    db = SystemSessionLocal()
    try:
        row = db.query(SchedulerMeta).filter(SchedulerMeta.job_name == job_name).first()
        return row.last_status if row else None
    finally:
        db.close()
