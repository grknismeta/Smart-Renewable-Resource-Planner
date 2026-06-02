from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from app import auth
from app.db import models
from app.schemas import schemas
from app.crud import crud
from app.db.database import get_db

# DÜZELTME: 'prefix' ve 'tags' parametrelerini buradan siliyoruz.
# Çünkü main.py dosyasında app.include_router(...) içinde zaten tanımladık.
# Eğer burada da bırakırsak adres "/users/users/register" olur ve 404 hatası alırsınız.
router = APIRouter()

# GÜV-2 (2026-06-01): basit brute-force koruması (in-memory). Bir e-posta için
# art arda N başarısız giriş → geçici kilit (429). Tek-instance deploy için
# yeterli; çok-worker/ölçek için ileride Redis tabanlı yapılabilir.
import time as _time
_LOGIN_ATTEMPTS: dict = {}            # key(email) -> [fail_count, lock_until_ts]
_MAX_LOGIN_FAILS = 5
_LOGIN_LOCKOUT_SECONDS = 300         # 5 dk

def _login_lock_remaining(key: str) -> int:
    rec = _LOGIN_ATTEMPTS.get(key)
    if not rec:
        return 0
    rem = int(rec[1] - _time.time())
    return rem if rem > 0 else 0

def _register_login_fail(key: str) -> None:
    rec = _LOGIN_ATTEMPTS.get(key, [0, 0.0])
    rec[0] += 1
    if rec[0] >= _MAX_LOGIN_FAILS:
        rec[1] = _time.time() + _LOGIN_LOCKOUT_SECONDS
        rec[0] = 0  # sayacı sıfırla; kilit süresi işliyor
    _LOGIN_ATTEMPTS[key] = rec

def _clear_login_fails(key: str) -> None:
    _LOGIN_ATTEMPTS.pop(key, None)


@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    """
    Yeni bir kullanıcı kaydı oluşturur.
    """
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Bu email adresi zaten kayıtlı."
        )
    
    new_user = crud.create_user(db=db, user=user)
    if not new_user:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Kullanıcı oluşturulurken bir hata oluştu."
        )
    return new_user

@router.post("/token", response_model=schemas.Token)
def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    """
    Kullanıcı girişi yapar ve JWT (Access Token) döndürür.
    """
    # GÜV-2: brute-force kilidi — çok başarısız denemede 429.
    _lock_key = (form_data.username or "").strip().lower()
    _rem = _login_lock_remaining(_lock_key)
    if _rem > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Çok fazla başarısız giriş. {_rem} saniye sonra tekrar deneyin.",
        )

    # 1. Kullanıcıyı doğrula
    user = auth.authenticate_user(db, form_data.username, form_data.password)

    # Pylance/Type check için sağlam kontrol
    # Sadece 'if not user' demek yerine, user'ın gerçekten bir User modeli olup olmadığına bakıyoruz.
    if not user or not isinstance(user, models.User):
        _register_login_fail(_lock_key)  # GÜV-2: başarısız deneme say
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    _clear_login_fails(_lock_key)  # GÜV-2: başarılı giriş → sayaç sıfırla
        
    # 2. Token oluştur
    # auth dosyasında bu değişken yoksa varsayılan 30 dk kullanılır
    expire_minutes = getattr(auth, "ACCESS_TOKEN_EXPIRE_MINUTES", 30)
    access_token_expires = timedelta(minutes=expire_minutes)
    
    access_token = auth.create_access_token(
        data={"sub": user.email}, 
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(auth.get_current_active_user)):
    """
    Geçerli token'a sahip kullanıcının bilgilerini döndürür.
    """
    return current_user


@router.patch("/me", response_model=schemas.UserResponse)
def update_users_me(
    payload: schemas.UserUpdate,
    current_user: models.User = Depends(auth.get_current_active_user),
    db: Session = Depends(get_db),
):
    """HESABIM (2026-06-02): profil güncelle (şimdilik yalnız ad-soyad)."""
    return crud.update_user_profile(db, current_user, payload.full_name)


@router.post("/me/change-password", status_code=status.HTTP_204_NO_CONTENT)
def change_my_password(
    payload: schemas.PasswordChange,
    current_user: models.User = Depends(auth.get_current_active_user),
    db: Session = Depends(get_db),
):
    """HESABIM (2026-06-02): parola değiştir. Mevcut parola doğrulanır.

    OAuth (Google) kullanıcılarının gerçek parolası yoktur (rastgele hash) →
    current_password eşleşmez, 400 döner. (İleride 'parola oluştur' akışı eklenebilir.)
    """
    if not auth.verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mevcut parola hatalı.",
        )
    if payload.new_password == payload.current_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Yeni parola eskisinden farklı olmalı.",
        )
    crud.update_user_password(db, current_user, payload.new_password)
    return None


@router.post("/me/set-password", status_code=status.HTTP_204_NO_CONTENT)
def set_my_password(
    payload: schemas.SetPassword,
    current_user: models.User = Depends(auth.get_current_active_user),
    db: Session = Depends(get_db),
):
    """HESABIM (2026-06-03): Parolası OLMAYAN (OAuth/Google) kullanıcı için İLK
    parola belirleme — mevcut parola istenmez. Zaten parolası varsa 400
    (change-password kullanılmalı)."""
    if current_user.has_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Zaten bir parolanız var. 'Şifre Değiştir'i kullanın.",
        )
    crud.update_user_password(db, current_user, payload.new_password)
    return None


@router.post("/auth/google", response_model=schemas.Token)
def login_with_google(payload: schemas.GoogleAuthRequest, db: Session = Depends(get_db)):
    """AUTH-3 (2026-06-01): Google ID-token ile giriş.

    Frontend Google'dan aldığı ID token'ı gönderir; tokeninfo ile doğrularız
    (audience = bizim client_id), e-posta ile kullanıcıyı oluştur/eşle, kendi
    JWT'mizi döndürürüz. Parola gerekmez (OAuth kullanıcısı).
    """
    try:
        claims = auth.verify_google_id_token(payload.id_token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Google girişi geçersiz: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = claims.get("email")
    full_name = claims.get("name")
    user = crud.get_or_create_oauth_user(db, email=email, full_name=full_name)
    if not user or not isinstance(user, models.User):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Kullanıcı oluşturulamadı.",
        )

    expire_minutes = getattr(auth, "ACCESS_TOKEN_EXPIRE_MINUTES", 30)
    access_token = auth.create_access_token(
        data={"sub": user.email},
        expires_delta=timedelta(minutes=expire_minutes),
    )
    return {"access_token": access_token, "token_type": "bearer"}