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
JOB_PROVINCE_ANALYSIS = "province_analysis_recompute"

_scheduler: Optional[BackgroundScheduler] = None


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
    """
    # Geç import — circular import ve startup sırasını kırar
    from .collectors.hourly import update_hourly_data
    from . import analysis_service

    update_hourly_data()
    analysis_service.recompute_all_provinces()


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

    _scheduler.start()
    logger.info("APScheduler baslatildi. Saatlik is kayitli: %s", JOB_HOURLY_FETCH)

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
        # İlk çalışma cron'u beklemesin — job'ı immediate tetikle.
        # BackgroundScheduler arka planda çalıştırır, startup'ı bloklamaz.
        _scheduler.add_job(
            func=lambda: _run_tracked(JOB_HOURLY_FETCH, _hourly_fetch_and_recompute),
            id=f"{JOB_HOURLY_FETCH}_startup",
            name="Startup'ta ilk calisma",
            max_instances=1,
            replace_existing=True,
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
