"""
SRRP — AI Chatbot Servisi (Aşama 3.C)
=====================================

Google Gemini tabanlı sohbet asistanı. Kullanıcının yatırım, harita ve
senaryo sorularına SRRP verisinden faydalanarak yanıt verir.

Mimari:
  * **System prompt** — chatbot'a SRRP'nin ne yaptığını, hangi veriye sahip
    olduğunu, nasıl yanıt vermesi gerektiğini söyler.
  * **Tool / Function calling** — chatbot uydurmasın diye gerçek veriye
    erişim yalnızca pre-defined tool'lar üzerinden. Text-to-SQL **yok**
    (güvenlik).
  * **Conversation history** — Redis 1 saat TTL ile per-user konuşma
    saklanır; uzun bağlamı koruyup aynı zamanda kota tüketmemek için.
  * **Lazy import** — `google-genai` bağımlılığı yoksa servis hata
    yerine "chatbot devre dışı" yanıtı verir (uygulama crash etmesin).

2026-05-17 — `google-generativeai` → `google-genai` SDK migration.
Eski SDK deprecated; yeni SDK `from google import genai` + `genai.Client`
+ `google.genai.types` namespace kullanır.

Kullanıcının Yapacağı Kurulum
-----------------------------
1. ``pip install google-genai``
2. ``.env`` dosyasına: ``GOOGLE_API_KEY=...``
3. Backend restart.

Detay: ``app/routers/chat.py``.
"""
from __future__ import annotations

import logging
import os
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, Optional

logger = logging.getLogger(__name__)

# ─── Gemini SDK lazy import (yeni: google-genai) ─────────────────────────────
_GEMINI_AVAILABLE = False
_GEMINI_IMPORT_ERROR: Optional[str] = None
try:
    from google import genai  # type: ignore
    from google.genai import types as genai_types  # type: ignore
    _GEMINI_AVAILABLE = True
except Exception as e:
    genai = None  # type: ignore
    genai_types = None  # type: ignore
    _GEMINI_IMPORT_ERROR = str(e)
    logger.warning(
        "[chatbot] google-genai import edilemedi: %s — chatbot devre dışı",
        _GEMINI_IMPORT_ERROR,
    )

# ─── Konfigürasyon ───────────────────────────────────────────────────────────
GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY", "").strip()
DEFAULT_MODEL = os.environ.get("GEMINI_MODEL", "gemini-flash-latest")
HISTORY_TTL_SECONDS = 3600  # 1 saat

# Module-level client singleton (yeni SDK Client-based)
_client: Optional[Any] = None


SYSTEM_PROMPT = """Sen SRRP'nin (Smart Renewable Resource Planner) yardımcı AI asistanısın.

SRRP, Türkiye için akıllı yenilenebilir enerji yatırım planlayıcısıdır:
- 81 il × ilçeler için saatlik hava durumu verisi (rüzgar, güneş, sıcaklık)
- Tematik harita: rüzgar/güneş/ısınım potansiyeli choropleth
- Senaryo yönetimi: Pin'lerle (rüzgar türbini, güneş paneli, hidroelektrik) yatırım planı oluşturma
- Finansal projeksiyon: CAPEX, LCOE, payback period, NPV, IRR, CO₂ avoidance

YANIT KURALLARI:
1. **Sadece tool sonuçlarına dayan** — uydurma. Tool'dan veri gelmediyse "elimde veri yok" de.
2. **Türkçe yanıt** ver. Teknik terimleri açıkla (örn. "LCOE — birim enerji başına maliyet").
3. **Sayısal sonuçları yorumla** — sadece sayı verme, ne anlama geldiğini açıkla.
4. **Kısa tut** — 3-4 paragrafı geçme. Tablolar markdown ile.
5. **Kullanıcı il sorduğunda** ilgili tool'u çağır (ör. `get_province_score`).
6. **Senaryo sorgusu** geldiğinde önce `get_scenario_financials` ile metrikleri al.
7. **Belirsizlikte sor** — "hangi kaynak için (rüzgar/güneş/hidro)?" gibi.

Türkiye coğrafi/idari yapısını bilirsin: 7 bölge (Marmara, Ege, Akdeniz, İç Anadolu, Karadeniz, Doğu Anadolu, Güneydoğu Anadolu), 81 il.

Rakam birimleri: USD bazlı (kullanıcı isterse TL'ye çevir, kur tool'dan gelir)."""


@dataclass
class ChatMessage:
    role: str          # "user" | "model" | "function"
    content: str
    tool_name: Optional[str] = None   # function role için
    tool_args: Optional[dict] = None  # user→function call
    timestamp: float = field(default_factory=time.time)

    def to_dict(self) -> dict:
        return {
            "role": self.role,
            "content": self.content,
            "tool_name": self.tool_name,
            "tool_args": self.tool_args,
            "timestamp": self.timestamp,
        }


@dataclass
class ChatResponse:
    """Frontend'e dönen sohbet yanıtı."""
    session_id: str
    message: str
    tool_calls: list[dict] = field(default_factory=list)
    error: Optional[str] = None


# ─── Conversation History (Redis-backed) ─────────────────────────────────────
def _history_key(session_id: str) -> str:
    return f"chat:history:{session_id}"


def _load_history(session_id: str) -> list[ChatMessage]:
    from app.services.redis_cache import cache_get
    raw = cache_get(_history_key(session_id))
    if not raw or not isinstance(raw, list):
        return []
    out: list[ChatMessage] = []
    for d in raw:
        try:
            out.append(ChatMessage(
                role=d["role"],
                content=d["content"],
                tool_name=d.get("tool_name"),
                tool_args=d.get("tool_args"),
                timestamp=d.get("timestamp", time.time()),
            ))
        except Exception:
            continue
    return out


def _save_history(session_id: str, history: list[ChatMessage]) -> None:
    from app.services.redis_cache import cache_set
    # Son 30 mesajı tut (token tasarrufu)
    trimmed = history[-30:]
    cache_set(
        _history_key(session_id),
        [m.to_dict() for m in trimmed],
        ttl_seconds=HISTORY_TTL_SECONDS,
    )


def is_chatbot_available() -> tuple[bool, str]:
    """Servis durumu — UI bunu kontrol edip "chatbot kapalı" gösterir.

    Returns:
        (available, reason): reason boş string ise her şey OK.
    """
    if not _GEMINI_AVAILABLE:
        return False, (
            "google-genai paketi yüklü değil. "
            "Backend ortamında 'pip install google-genai' çalıştırın."
        )
    if not GOOGLE_API_KEY:
        return False, (
            "GOOGLE_API_KEY env değişkeni ayarlanmamış. "
            ".env dosyasına ekleyin ve backend'i yeniden başlatın."
        )
    return True, ""


def _get_client():
    """Gemini Client singleton — yeni SDK pattern.

    Yeni SDK `genai.configure()` yerine `genai.Client(api_key=...)` kullanır.
    Client thread-safe; tek instance yeterli.
    """
    global _client
    if not _GEMINI_AVAILABLE or not GOOGLE_API_KEY:
        return None
    if _client is None:
        try:
            _client = genai.Client(api_key=GOOGLE_API_KEY)  # type: ignore
        except Exception as e:
            logger.warning("[chatbot] genai.Client init hatası: %s", e)
            return None
    return _client


def new_session_id() -> str:
    """Yeni sohbet oturumu — frontend bunu saklar ve sonraki çağrılarda yollar."""
    return uuid.uuid4().hex[:16]


# ─── Tool registry ───────────────────────────────────────────────────────────
# Gerçek implementasyonlar `app/services/chatbot_tools.py`'de.

def _safe_response_text(response: Any) -> str:
    """Gemini response.text güvenli accessor.

    `response.text` shortcut'u response'da function_call part'ı olduğunda
    `ValueError: could not convert 'part.function_call' to text` fırlatır
    (özellikle ikinci tur tool response). Bu fonksiyon `.text` çağrısını
    try-except ile sarar, hata olursa `parts` listesini manuel gezip
    text olanları toplar — function_call parçaları atlanır.
    """
    try:
        t = response.text  # may raise if non-text parts exist
        return (t or "").strip()
    except Exception:
        pass
    out: list[str] = []
    try:
        for part in response.candidates[0].content.parts:
            t = getattr(part, "text", None)
            if t:
                out.append(t)
    except Exception as e:  # noqa: BLE001
        logger.warning("[chatbot] response parts parse hata: %s", e)
    return "\n".join(out).strip()


def _execute_tool(name: str, args: dict, current_user_id: Optional[int]) -> Any:
    """Tool dispatcher — chatbot bir fonksiyon çağırınca buraya düşer.

    Tool fonksiyonları `app/services/chatbot_tools.py`'de.
    """
    try:
        from app.services import chatbot_tools  # type: ignore
        fn = getattr(chatbot_tools, name, None)
        if fn is None:
            return {"error": f"Tool '{name}' tanımlı değil"}
        return fn(args, current_user_id)
    except ImportError:
        return {
            "error": f"Tool '{name}' modülü import edilemedi",
            "args_received": args,
        }
    except Exception as e:
        logger.exception("[chatbot] Tool '%s' çalıştırılırken hata", name)
        return {"error": str(e)}


# ─── Ana chat endpoint mantığı (google-genai SDK) ───────────────────────────

def chat(
    user_message: str,
    session_id: Optional[str],
    current_user_id: Optional[int] = None,
) -> ChatResponse:
    """Tek bir kullanıcı mesajını işler, yanıt döner.

    Args:
        user_message: Kullanıcının metin sorusu.
        session_id: Önceki konuşma id'si — yoksa yeni oluşturulur.
        current_user_id: Tool'lar kullanıcı bağlamı gerektirebilir (senaryo
            erişimi vb.).
    """
    available, reason = is_chatbot_available()
    if not available:
        return ChatResponse(
            session_id=session_id or "",
            message="",
            error=reason,
        )

    sid = session_id or new_session_id()
    history = _load_history(sid)
    history.append(ChatMessage(role="user", content=user_message))

    client = _get_client()
    if client is None:
        return ChatResponse(
            session_id=sid,
            message="",
            error="Gemini client başlatılamadı (GOOGLE_API_KEY veya SDK sorunu).",
        )

    try:
        # Tool tanımları (chatbot_tools.py yeni SDK ile uyumlu)
        try:
            from app.services.chatbot_tools import GEMINI_TOOL_DECLARATIONS  # type: ignore
            tool_defs = GEMINI_TOOL_DECLARATIONS
        except ImportError:
            tool_defs = None

        # Yeni SDK: GenerateContentConfig içinde system_instruction + tools
        config_kwargs: dict = {
            "system_instruction": SYSTEM_PROMPT,
        }
        if tool_defs:
            config_kwargs["tools"] = tool_defs

        config = genai_types.GenerateContentConfig(**config_kwargs)  # type: ignore

        # Konuşma geçmişini Gemini Content[] formatına çevir
        gemini_history: list = []
        for m in history[:-1]:  # son user mesajı dışında
            if m.role in ("user", "model"):
                gemini_history.append(
                    genai_types.Content(  # type: ignore
                        role=m.role,
                        parts=[genai_types.Part(text=m.content)],  # type: ignore
                    )
                )

        # Yeni SDK chat session: client.chats.create(model=, config=, history=)
        chat_session = client.chats.create(
            model=DEFAULT_MODEL,
            config=config,
            history=gemini_history,
        )
        response = chat_session.send_message(user_message)

        # Tool call var mı kontrol et — Gemini function calling
        tool_calls_made: list[dict] = []
        # Tek-tur tool çağrısı (recursive değil, basit ilk versiyon)
        try:
            candidates = getattr(response, "candidates", None) or []
            if candidates:
                parts = getattr(candidates[0].content, "parts", []) or []
                for part in parts:
                    fn_call = getattr(part, "function_call", None)
                    if fn_call is not None and getattr(fn_call, "name", None):
                        # Yeni SDK fn_call.args zaten dict
                        args = dict(getattr(fn_call, "args", None) or {})
                        result = _execute_tool(fn_call.name, args, current_user_id)
                        tool_calls_made.append({
                            "name": fn_call.name,
                            "args": args,
                            "result": result,
                        })
                        # Tool sonucunu modele geri gönder — yeni SDK Part API
                        response = chat_session.send_message(
                            genai_types.Part.from_function_response(  # type: ignore
                                name=fn_call.name,
                                response={"result": result},
                            )
                        )
        except Exception as tool_err:
            logger.warning("[chatbot] Tool dispatch hatası: %s", tool_err)

        final_text = _safe_response_text(response)
        history.append(ChatMessage(
            role="model",
            content=final_text,
            tool_args={"tool_calls": tool_calls_made} if tool_calls_made else None,
        ))
        _save_history(sid, history)

        return ChatResponse(
            session_id=sid,
            message=final_text,
            tool_calls=tool_calls_made,
        )

    except Exception as e:
        logger.exception("[chatbot] Gemini çağrısı hatası")
        return ChatResponse(
            session_id=sid,
            message="",
            error=f"Sohbet asistanı hatası: {e}",
        )


def reset_session(session_id: str) -> None:
    """Konuşma geçmişini temizle (kullanıcı 'yeniden başla' butonu)."""
    from app.services.redis_cache import cache_delete
    cache_delete(_history_key(session_id))
