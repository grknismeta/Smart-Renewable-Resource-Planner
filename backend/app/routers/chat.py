"""
SRRP — AI Chatbot Router (Aşama 3.C)
====================================

Endpoints:
  * ``POST /chat``           — kullanıcı mesajı gönder, yanıt al
  * ``POST /chat/reset``     — konuşma geçmişini temizle
  * ``GET  /chat/status``    — chatbot servis durumu (UI'da "kapalı" göstergesi için)

Konuşma kimliği (`session_id`) frontend tarafında saklanır ve her çağrıda
yollanır. Boşsa backend yeni oturum açar ve yanıtla birlikte döndürür.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from app import auth
from app.db import models
from app.services import chatbot_service

router = APIRouter(prefix="/chat", tags=["🤖 AI Chatbot"])


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    session_id: Optional[str] = Field(
        None, description="Önceki oturum id'si — yoksa yeni oluşturulur"
    )


class ChatResponseModel(BaseModel):
    session_id: str
    message: str
    tool_calls: list[dict] = Field(default_factory=list)
    error: Optional[str] = None


class StatusResponse(BaseModel):
    available: bool
    reason: str = ""
    model: Optional[str] = None


@router.get("/status", response_model=StatusResponse)
def chatbot_status():
    """Chatbot kullanılabilir mi — UI bunu kontrol edip kapalıysa
    "Kurulum gerekli" gösterir."""
    available, reason = chatbot_service.is_chatbot_available()
    return StatusResponse(
        available=available,
        reason=reason,
        model=chatbot_service.DEFAULT_MODEL if available else None,
    )


@router.post("", response_model=ChatResponseModel)
def chat(
    req: ChatRequest,
    current_user: models.User = Depends(auth.get_current_active_user),
):
    """Kullanıcı mesajını işler, Gemini yanıtını döner.

    Tool çağrıları varsa server-side çalıştırılır ve sonuçlar modele geri
    yollanır — final text yanıt + çağrılan tool'ların listesi döner
    (UI tool bilgisini "Manisa skorunu hesaplıyor..." benzeri göstergede
    kullanabilir).
    """
    resp = chatbot_service.chat(
        user_message=req.message,
        session_id=req.session_id,
        current_user_id=current_user.id,  # type: ignore
    )
    if resp.error and not resp.session_id:
        # Servis kapalı (paket yok / API key yok)
        raise HTTPException(status_code=503, detail=resp.error)
    return ChatResponseModel(
        session_id=resp.session_id,
        message=resp.message,
        tool_calls=resp.tool_calls,
        error=resp.error,
    )


@router.post("/reset")
def chat_reset(
    session_id: str,
    current_user: models.User = Depends(auth.get_current_active_user),
):
    """Konuşma geçmişini temizle (yeniden başla)."""
    chatbot_service.reset_session(session_id)
    return {"ok": True, "session_id": session_id}
