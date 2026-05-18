# backend/app/core/security.py
from datetime import datetime, timedelta, timezone
from typing import Any, Union
from jose import jwt
from passlib.context import CryptContext
from app.core.config import settings

# Şifreleri bcrypt algoritmasıyla dönüştürücü motor
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # Token 1 hafta geçerli

def get_password_hash(password: str) -> str:
    """Şifreyi kriptolar (hashler)"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Kullanıcının girdiği şifre ile veritabanındaki kriptolu şifreyi karşılaştırır"""
    return pwd_context.verify(plain_password, hashed_password)

# Fonksiyonun hem string (email) hem de UUID (ID) ile sorunsuz çalışmasını sağlamak için 'Union' kullandık
def create_access_token(subject: Union[str, Any]) -> str:
    """
    Giriş yapan kullanıcıya dijital kimlik kartı (JWT) üretir
    Subject kısmında genellikle kullanıcının email adresi veya UUID'si tutulur.
    """
    # GÜNCELLEME: utcnow() yerine modern timezone-aware now() kullanıyoruz
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    # Token içeriği (Payload)
    to_encode = {
        "exp": expire, 
        "sub": str(subject) # Citizen'ın ID'sini veya Email'ini burada taşıyoruz
    }
    
    # Dijital imzalı token üretimi
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt