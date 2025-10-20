from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

import schemas
from database import SessionLocal
from models import User 

# --- Security Constants and Settings ---

# Token expiration time (in minutes)
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Secret key for JWT (Should be strong and managed via .env in production)
SECRET_KEY = "Sakin_Burayi_Degistirmeyi_Unutma_SRRP_Gizli_Anahtari"
ALGORITHM = "HS256"

# Password hashing context (using bcrypt)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme: Tells FastAPI how to fetch the token from the request header
# Token endpoint: "/users/token" (defined in routers/users.py)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="users/token")


# --- Password Functions ---

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Compares the plain text password with the hashed password."""
    # Düzeltme: Karşılaştırma sırasında parolanın kesilmesi GEREKMEZ, passlib bunu doğru yapar.
    # Sadece hashing (get_password_hash) sırasında kesilir.
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Hashes the plain text password. Truncates if longer than 72 bytes due to bcrypt limitation."""
    # CRITICAL FIX: Truncate password to 72 bytes before hashing to prevent ValueError.
    if len(password.encode('utf-8')) > 10000:
        password = password.encode('utf-8')[:10000].decode('utf-8', 'ignore')

    return pwd_context.hash(password)


# --- JWT (Token) Functions ---

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    """Creates a JWT using the provided data (usually user identifier)."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    
    # Creates the JWT
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_db():
    """Database session dependency (Generator)"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Security Dependency ---

def get_current_user(
    db: Session = Depends(get_db), 
    token: str = Depends(oauth2_scheme)
) -> User:
    """
    Validates the token from the request and returns the corresponding User object.
    Raises 401 Unauthorized error on failure.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik bilgileri doğrulanamadı",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # 1. Decode the token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # 2. Get email from the token
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        
        # 3. Validate the email with the Pydantic model
        token_data = schemas.TokenData(email=email)
    
    except JWTError:
        # Token expired or invalid
        raise credentials_exception

    # 4. Find the user in the database
    # NOTE: Assuming a simple query here; ideally this would call crud.get_user_by_email
    from models import User
    user = db.query(User).filter(User.email == token_data.email).first()
    
    if user is None:
        raise credentials_exception
    
    return user
