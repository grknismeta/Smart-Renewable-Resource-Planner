from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

# Updated imports
from backend.schemas import schemas
from backend.crud import crud
from backend.db import models
from backend.db.database import SystemSessionLocal, get_db

# --- Security Constants and Settings ---
ACCESS_TOKEN_EXPIRE_MINUTES = 2880
SECRET_KEY = "Sakin_Burayi_Degistirmeyi_Unutma_SRRP_Gizli_Anahtari"
ALGORITHM = "HS256"
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

# (DÜZELTME) tokenUrl, routers/users.py dosyasındakiyle eşleşmeli
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/users/token") 


# --- Password Functions ---

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Düz metin parolayı hashlenmiş parolayla karşılaştırır."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """
    Düz metin parolayı hashler.
    (HATA DÜZELTMESİ: Gereksiz 10000 karakter kontrolü kaldırıldı. 
    passlib/bcrypt 72 byte limitini zaten kendi içinde yönetir.)
    """
    return pwd_context.hash(password)


# --- JWT (Token) Functions ---

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    """JWT oluşturur."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- Authentication Function (YENİ) ---

def authenticate_user(db: Session, email: str, password: str) -> models.User | bool:
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


# --- Security Dependency ---

def get_current_user(
    db: Session = Depends(get_db), 
    token: str = Depends(oauth2_scheme)
) -> models.User:
    """
    (HATA DÜZELTMESİ)
    Token'ı doğrular ve ilgili User modelini döndürür.
    """
    
    # --- YENİ DEBUG KODU ---
    # Bu print, 401 hatasından hemen önce çalışacak
    print("\n--- AUTH.PY DEBUG ---")
    print(f"Token doğrulama fonksiyonu tetiklendi.")
    print(f"Gelen Token: {token}")
    print("---------------------\n")
    # --- DEBUG KODU SONU ---

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik bilgileri doğrulanamadı",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        if not isinstance(email, str):
            raise credentials_exception
        token_data = schemas.TokenData(email=email)
    
    except JWTError:
        raise credentials_exception

    # (DÜZELTME) Doğrudan sorgu yerine CRUD fonksiyonu kullanıldı
    # tipi zaten 'str' olarak garantilenmiş olan 'email' değişkenini kullanın.
    user = crud.get_user_by_email(db, email=email) # <-- Kırmızı çizgi burada kaybolacak
    
    if user is None:
        raise credentials_exception
    
    return user

def get_current_active_user(
    current_user: models.User = Depends(get_current_user)
) -> models.User:
    """
    (YENİ) Sadece aktif kullanıcıların işlem yapabilmesi için
    (Şimdilik tüm kullanıcılar aktif sayılıyor)
    """
    # if current_user.disabled:
    #     raise HTTPException(status_code=400, detail="Inactive user")
    return current_user
