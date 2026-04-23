"""/system/* endpoint'leri — Scheduler durumu.

Frontend'in "X dk önce güncellendi" metni gerçek `last_scheduler_run` zamanını
göstersin diye `/system/status` endpoint'i `scheduler_meta` tablosundan okur.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_system_db
from app.db.models import SchedulerMeta
from app.services.scheduler import JOB_HOURLY_FETCH

router = APIRouter(prefix="/system", tags=["system"])


def _minutes_since(dt: Optional[datetime]) -> Optional[float]:
    if dt is None:
        return None
    # scheduler_meta'daki DateTime(timezone=True) → tz-aware
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    delta = now - dt
    return round(delta.total_seconds() / 60.0, 1)


def _job_to_dict(row: SchedulerMeta) -> Dict:
    return {
        "job_name": row.job_name,
        "last_run_at": row.last_run_at.isoformat() if row.last_run_at else None,
        "next_run_at": row.next_run_at.isoformat() if row.next_run_at else None,
        "last_status": row.last_status,
        "last_duration_seconds": row.last_duration_seconds,
        "last_error": row.last_error,
        "run_count": row.run_count or 0,
        "minutes_since_last_run": _minutes_since(row.last_run_at),
    }


@router.get("/status")
def system_status(db: Session = Depends(get_system_db)):
    """
    Scheduler durumunu döner. Frontend MapScreen üstündeki tazelik rozeti
    `hourly_weather_fetch.minutes_since_last_run` değerini kullanır.
    """
    rows: List[SchedulerMeta] = db.query(SchedulerMeta).all()
    jobs = {r.job_name: _job_to_dict(r) for r in rows}

    primary = jobs.get(JOB_HOURLY_FETCH)
    return {
        "server_time": datetime.now(timezone.utc).isoformat(),
        "primary_job": JOB_HOURLY_FETCH,
        "last_scheduler_run": primary.get("last_run_at") if primary else None,
        "next_scheduler_run": primary.get("next_run_at") if primary else None,
        "minutes_since_last_run": (
            primary.get("minutes_since_last_run") if primary else None
        ),
        "status": primary.get("last_status") if primary else "unknown",
        "jobs": jobs,
    }
