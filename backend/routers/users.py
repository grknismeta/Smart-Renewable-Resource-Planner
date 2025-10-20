# routers/users.py

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

import schemas
import models
import crud
import auth # Token oluşturma ve parola doğrulama fonksiyonları
from database import SessionLocal # Veritabanı Dependency için

# API uç noktalarını gruplamak ve bir önek (prefix) atamak için APIRouter kullanıyoruz.
router = APIRouter(
    prefix="/users",
    tags=["Kullanıcı & Kimlik Doğrulama"],
    # Genel hata mesajları eklenebilir
)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Token'ın geçerli kalacağı süreyi auth.py'den çekiyoruz
ACCESS_TOKEN_EXPIRE_MINUTES = auth.ACCESS_TOKEN_EXPIRE_MINUTES

# --- 1. Kullanıcı Kayıt Uç Noktası ---
# Yeni bir kullanıcı oluşturmak için kullanılır.
@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    
    # 1. Kullanıcının zaten var olup olmadığını kontrol et
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu e-posta adresi zaten kayıtlı."
        )
        
    # 2. Kullanıcıyı veritabanına kaydet (Parola şifreleme crud.py içinde yapılır)
    new_user = crud.create_user(db=db, user=user)
    
    return new_user

# --- 2. Kullanıcı Giriş Uç Noktası (Token Alma) ---
# Kullanıcının kimlik bilgilerini doğrulayarak bir Access Token döndürür.
# OAuth2PasswordRequestForm kullanılır (FastAPI standartı)
@router.post("/token", response_model=schemas.Token)
def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), # form_data: username (email) ve password içerir
    db: Session = Depends(get_db)
):
    # 1. Kullanıcıyı email ile veritabanında bul
    user = crud.get_user_by_email(db, email=form_data.username)
    
    # 2. Kullanıcı yoksa veya parola yanlışsa hata döndür
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Hatalı e-posta veya parola.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # 3. Token'ın süresini belirle
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    # 4. Access Token oluştur (JWT payload'ı olarak email'i kullanıyoruz)
    access_token = auth.create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    
    # 5. Token'ı döndür
    return {"access_token": access_token, "token_type": "bearer"}

# --- 3. Giriş Yapmış Kullanıcı Bilgisini Çekme Uç Noktası ---
# Sadece geçerli bir token'a sahip kullanıcılar bu endpoint'e erişebilir.
@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    """Giriş yapmış kullanıcının bilgilerini döndürür."""
    # auth.get_current_user fonksiyonu token'ı doğruladı ve kullanıcı nesnesini döndürdü.
    return current_user