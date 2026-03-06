"""
Merkezi loglama modülü — loguru tabanlı.
Kullanım:
    from app.core.logger import logger
    logger.info("Mesaj")
    logger.warning("Uyarı: {}", detay)
    logger.error("Hata: {}", exc)
"""

import sys
from loguru import logger

# Varsayılan handler'ı kaldır (kendi formatımızı ekleyeceğiz)
logger.remove()

# --- Renkli konsol çıktısı ---
logger.add(
    sys.stderr,
    format=(
        "<green>{time:HH:mm:ss}</green> | "
        "<level>{level: <8}</level> | "
        "<cyan>{name}</cyan>:<cyan>{line}</cyan> — "
        "<level>{message}</level>"
    ),
    level="DEBUG",
    colorize=True,
)

# --- Dosya loglama (hata ve üzeri, 7 gün sakla) ---
logger.add(
    "logs/srrp_{time:YYYY-MM-DD}.log",
    rotation="1 day",
    retention="7 days",
    level="WARNING",
    encoding="utf-8",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{line} — {message}",
)

__all__ = ["logger"]
