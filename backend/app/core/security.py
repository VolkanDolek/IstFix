# backend/app/core/security.py
from datetime import datetime, timedelta
from jose import jwt
from passlib.context import CryptContext
from app.core.config import settings

# Şifreleri bcrypt algoritmasıyla dönüştürücü motor
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # Token 1 hafta geçerli

def get_password_hash(password: str):
    """Şifreyi kriptolar (hashler)"""
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    """Kullanıcının girdiği şifre ile veritabanındaki kriptolu şifreyi karşılaştırır"""
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    """Giriş yapan kullanıcıya dijital kimlik kartı (JWT) üretir"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt