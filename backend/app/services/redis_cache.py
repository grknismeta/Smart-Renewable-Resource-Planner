"""
SRRP v2.0 — Redis Cache Servisi
Ağır endpoint sonuçlarını önbelleğe alarak performansı artırır.
"""
import json
import os
import logging
from typing import Optional, Any
from functools import wraps

logger = logging.getLogger(__name__)

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

def cache_get(key: str) -> Optional[Any]:
    """Cache'den veri oku. Redis yoksa None döner."""
    if not REDIS_AVAILABLE:
        return None
    try:
        data = redis_client.get(key)
        if data:
            return json.loads(data)
    except Exception as e:
        logger.error(f"Cache okuma hatası: {e}")
    return None


def cache_set(key: str, value: Any, ttl_seconds: int = 3600) -> bool:
    """Cache'e veri yaz. Varsayılan TTL: 1 saat."""
    if not REDIS_AVAILABLE:
        return False
    try:
        redis_client.setex(key, ttl_seconds, json.dumps(value, default=str))
        return True
    except Exception as e:
        logger.error(f"Cache yazma hatası: {e}")
        return False


def cache_delete(key: str) -> bool:
    """Cache'den veri sil."""
    if not REDIS_AVAILABLE:
        return False
    try:
        redis_client.delete(key)
        return True
    except Exception as e:
        logger.error(f"Cache silme hatası: {e}")
        return False


def cache_delete_pattern(pattern: str) -> int:
    """Belirli bir pattern'e uyan tüm key'leri sil."""
    if not REDIS_AVAILABLE:
        return 0
    try:
        keys = redis_client.keys(pattern)
        if keys:
            return redis_client.delete(*keys)
    except Exception as e:
        logger.error(f"Cache pattern silme hatası: {e}")
    return 0


def cache_flush() -> bool:
    """Tüm cache'i temizle."""
    if not REDIS_AVAILABLE:
        return False
    try:
        redis_client.flushdb()
        return True
    except Exception as e:
        logger.error(f"Cache flush hatası: {e}")
        return False


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
