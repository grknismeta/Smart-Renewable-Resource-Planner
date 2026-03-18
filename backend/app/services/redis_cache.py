"""
SRRP v2.0 — Cache Servisi
Ağır endpoint sonuçlarını önbelleğe alarak performansı artırır.

Katmanlı strateji:
  1. Redis (üretim ortamı — REDIS_URL env değişkeni gerekli)
  2. In-memory TTL cache (Redis yoksa otomatik devreye girer)

Her iki katman da aynı API ile kullanılır; uygulama kodu
Redis varlığından haberdar olmak zorunda değildir.
"""
import json
import os
import time
import logging
from threading import Lock
from typing import Optional, Any, Tuple
from functools import wraps

logger = logging.getLogger(__name__)

# ─── In-Memory TTL Cache ────────────────────────────────────────────────────
# Yapı: { key: (value, expire_at_float) }
# Thread-safe: Lock ile korunur.
_mem_store: dict = {}
_mem_lock = Lock()


def _mem_get(key: str) -> Optional[Any]:
    with _mem_lock:
        entry = _mem_store.get(key)
        if entry is None:
            return None
        value, expire_at = entry
        if time.monotonic() > expire_at:
            del _mem_store[key]
            return None
        return value


def _mem_set(key: str, value: Any, ttl_seconds: int) -> None:
    with _mem_lock:
        _mem_store[key] = (value, time.monotonic() + ttl_seconds)


def _mem_delete(key: str) -> None:
    with _mem_lock:
        _mem_store.pop(key, None)


def _mem_flush() -> None:
    with _mem_lock:
        _mem_store.clear()


def _mem_delete_pattern(pattern: str) -> int:
    """Basit glob-style wildcard: 'prefix:*' şeklindeki pattern'leri destekler."""
    prefix = pattern.rstrip("*")
    with _mem_lock:
        keys_to_del = [k for k in _mem_store if k.startswith(prefix)]
        for k in keys_to_del:
            del _mem_store[k]
    return len(keys_to_del)

# --- Redis Bağlantısı ---
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

try:
    import redis
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    # Bağlantıyı test et
    redis_client.ping()
    REDIS_AVAILABLE = True
    logger.info("✅ Redis bağlantısı başarılı")
except Exception as e:
    redis_client = None
    REDIS_AVAILABLE = False
    logger.warning(f"⚠️ Redis bağlantısı kurulamadı: {e}. Cache devre dışı.")


# --- Cache İşlemleri ---
# Her fonksiyon: Redis varsa Redis kullan, yoksa in-memory fallback.

def cache_get(key: str) -> Optional[Any]:
    """Cache'den veri oku. Redis → in-memory fallback zinciri."""
    if REDIS_AVAILABLE:
        try:
            data = redis_client.get(key)
            if data:
                return json.loads(data)
        except Exception as e:
            logger.error(f"Redis okuma hatası: {e}")
    # In-memory fallback
    return _mem_get(key)


def cache_set(key: str, value: Any, ttl_seconds: int = 3600) -> bool:
    """Cache'e veri yaz. Varsayılan TTL: 1 saat. Her iki katmana da yazar."""
    if REDIS_AVAILABLE:
        try:
            redis_client.setex(key, ttl_seconds, json.dumps(value, default=str))
            return True
        except Exception as e:
            logger.error(f"Redis yazma hatası: {e}")
    # In-memory fallback (Redis başarısız olsa da yazar)
    _mem_set(key, value, ttl_seconds)
    return True


def cache_delete(key: str) -> bool:
    """Cache'den veri sil (her iki katmandan)."""
    deleted = False
    if REDIS_AVAILABLE:
        try:
            redis_client.delete(key)
            deleted = True
        except Exception as e:
            logger.error(f"Redis silme hatası: {e}")
    _mem_delete(key)
    return deleted


def cache_delete_pattern(pattern: str) -> int:
    """Belirli bir pattern'e uyan tüm key'leri sil ('prefix:*' formatı)."""
    count = _mem_delete_pattern(pattern)
    if REDIS_AVAILABLE:
        try:
            keys = redis_client.keys(pattern)
            if keys:
                count += redis_client.delete(*keys)
        except Exception as e:
            logger.error(f"Redis pattern silme hatası: {e}")
    return count


def cache_flush() -> bool:
    """Tüm cache'i temizle (her iki katman)."""
    _mem_flush()
    if REDIS_AVAILABLE:
        try:
            redis_client.flushdb()
        except Exception as e:
            logger.error(f"Redis flush hatası: {e}")
            return False
    return True


# --- Dekoratör ---

def cached(key_prefix: str, ttl_seconds: int = 3600):
    """
    Endpoint sonuçlarını cache'leyen dekoratör.
    
    Kullanım:
        @cached("reports:regional", ttl_seconds=1800)
        async def get_regional_report(region: str, type: str):
            ...
    """
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Cache key oluştur (argümanlardan)
            key_parts = [key_prefix]
            for v in kwargs.values():
                if v is not None:
                    key_parts.append(str(v))
            cache_key = ":".join(key_parts)
            
            # Cache'de var mı kontrol et
            result = cache_get(cache_key)
            if result is not None:
                logger.debug(f"Cache HIT: {cache_key}")
                return result
            
            # Yoksa fonksiyonu çalıştır
            logger.debug(f"Cache MISS: {cache_key}")
            result = await func(*args, **kwargs)
            
            # Sonucu cache'le
            cache_set(cache_key, result, ttl_seconds)
            return result
        return wrapper
    return decorator
