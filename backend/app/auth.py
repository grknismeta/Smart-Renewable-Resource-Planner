import os
from datetime import datetime, timedelta, timezone
from typing import Union
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from dotenv import load_dotenv

# İçe aktarmalar düzeltildi: package yerine modülleri import ediyoruz
from .crud import crud
from .schemas import schemas
from .db.database import get_db, Session

# .env dosyasını yükle
load_dotenv()

# GÜVENLİK GÜNCELLEMESİ: Değerleri .env dosyasından çekiyoruz
_SECRET_FALLBACK = "uyari_lutfen_env_dosyasi_olustur"
SECRET_KEY = os.getenv("SECRET_KEY", _SECRET_FALLBACK)
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))

# GÜV-1 (2026-06-01): SECRET_KEY .env'de set edilmemişse JWT'ler TAHMİN EDİLEBİLİR
# (forgeable) → ciddi güvenlik açığı. Deploy'dan ÖNCE mutlaka güçlü bir değer set
# edilmeli. Zayıf/varsayılan/kısa fallback kullanılıyorsa başlangıçta CRITICAL uyarı.
if SECRET_KEY == _SECRET_FALLBACK or len(SECRET_KEY) < 32:
    import logging as _logging
    _logging.getLogger(__name__).critical(
        "[GUVENLIK] SECRET_KEY zayif/varsayilan! .env'de guclu bir SECRET_KEY "
        "(>=32 rastgele karakter) set edin; aksi halde JWT'ler taklit edilebilir. "
        "Uret: python -c \"import secrets;print(secrets.token_urlsafe(48))\""
    )

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="users/token")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def authenticate_user(db: Session, email: str, password: str):
    """
    Kullanıcıyı email ve parolaya göre doğrular.
    Başarılıysa User modelini, değilse False döndürür.
    """
    user = crud.get_user_by_email(db, email)
    if not user:
        return False # Kullanıcı bulunamadı
    if not verify_password(password, str(user.hashed_password)):
        return False # Şifre yanlış
    
    return user

def create_access_token(data: dict, expires_delta: Union[timedelta, None] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt



async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik doğrulanamadı",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        token_data = schemas.TokenData(email=email)
    except JWTError:
        raise credentials_exception
    user = crud.get_user_by_email(db, email=token_data.email)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: schemas.UserResponse = Depends(get_current_user)):
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Kullanıcı aktif değil")
    return current_user


# ─── GOOGLE OAUTH (AUTH-3, 2026-06-01) ───────────────────────────────────────
# ID-token akışı: frontend Google'dan ID token alır → buraya gönderir → tokeninfo
# ile doğrularız (audience = bizim client_id). Redirect/secret gerekmez.
# Client ID PUBLIC'tir (frontend'e gömülür), .env'de override edilebilir.
GOOGLE_CLIENT_ID = os.getenv(
    "GOOGLE_CLIENT_ID",
    "756480872473-fm4vb6j5u3ic9c5fhbrr0jhkmrl74m7e.apps.googleusercontent.com",
)
# Mobil client'lar eklenince audience listesine girer.
GOOGLE_ALLOWED_AUDIENCES = {
    a for a in [
        GOOGLE_CLIENT_ID,
        os.getenv("GOOGLE_ANDROID_CLIENT_ID"),
        os.getenv("GOOGLE_IOS_CLIENT_ID"),
    ] if a
}


def verify_google_id_token(id_token_str: str) -> dict:
    """Google ID token'ı tokeninfo endpoint'iyle doğrular.

    Geçerliyse claim dict'i (email, name, aud, iss...) döner; geçersizse
    ValueError fırlatır. Ekstra paket gerektirmez (stdlib urllib).
    """
    import json as _json
    import urllib.request as _urlreq
    import urllib.parse as _urlparse

    if not id_token_str or not isinstance(id_token_str, str):
        raise ValueError("id_token boş")
    url = "https://oauth2.googleapis.com/tokeninfo?" + _urlparse.urlencode(
        {"id_token": id_token_str}
    )
    try:
        with _urlreq.urlopen(url, timeout=10) as resp:
            if resp.status != 200:
                raise ValueError("token doğrulanamadı")
            claims = _json.loads(resp.read().decode("utf-8"))
    except ValueError:
        raise
    except Exception as e:
        raise ValueError(f"Google token doğrulama hatası: {e}")

    if claims.get("aud") not in GOOGLE_ALLOWED_AUDIENCES:
        raise ValueError("aud (client_id) eşleşmiyor")
    if claims.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise ValueError("iss geçersiz")
    if not claims.get("email"):
        raise ValueError("e-posta yok")
    if str(claims.get("email_verified")).lower() != "true":
        raise ValueError("e-posta doğrulanmamış")
    return claims
