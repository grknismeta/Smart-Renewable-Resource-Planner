# routers/users.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from .. import crud, schemas, auth, models
from ..database import SessionLocal
from ..database import get_db

router = APIRouter(
    prefix="/users",
    tags=["Users"]
)

# Dependency (get_db)

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
    Form verisi olarak 'username' (bizim senaryomuzda email) ve 'password' bekler.
    """
    # 1. Kullanıcıyı doğrula (Biz 'username' olarak email kullanıyoruz)
    user = auth.authenticate_user(db, form_data.username, form_data.password)
    
    # DÜZELTME: 'if not user:' yerine 'isinstance' kullanarak
    # Pylance'in tip daraltması yapmasını sağlıyoruz.
    if not isinstance(user, models.User):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # Bu noktadan sonra Pylance, 'user' değişkeninin
    # 'models.User' tipinde olduğunu bilir.
    # 2. Token oluştur
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.email}, # 'sub' (subject) olarak email'i kullanıyoruz
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(auth.get_current_active_user)):
    """
    Geçerli token'a sahip kullanıcının bilgilerini döndürür.
    """
    return current_user
