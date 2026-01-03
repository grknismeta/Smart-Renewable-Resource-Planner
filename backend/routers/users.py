from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from backend import auth
from backend.db import models
from backend.schemas import schemas
from backend.crud import crud
from backend.db.database import get_db

# DÜZELTME: 'prefix' ve 'tags' parametrelerini buradan siliyoruz.
# Çünkü main.py dosyasında app.include_router(...) içinde zaten tanımladık.
# Eğer burada da bırakırsak adres "/users/users/register" olur ve 404 hatası alırsınız.
router = APIRouter()

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
    # 1. Kullanıcıyı doğrula
    user = auth.authenticate_user(db, form_data.username, form_data.password)
    
    # Pylance/Type check için sağlam kontrol
    # Sadece 'if not user' demek yerine, user'ın gerçekten bir User modeli olup olmadığına bakıyoruz.
    if not user or not isinstance(user, models.User):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
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