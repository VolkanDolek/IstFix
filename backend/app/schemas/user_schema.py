# backend/app/schemas/user_schema.py
from pydantic import BaseModel, EmailStr
from datetime import datetime

# Flutter'dan Kayıt Olurken Gelecek Veri (Giriş)
class UserCreate(BaseModel):
    email: EmailStr  # Sadece geçerli email formatını kabul eder (@ işareti vb.)
    password: str

# API'den Flutter'a Dönecek Veri (Çıkış - Şifre Yok!)
class UserResponse(BaseModel):
    id: int
    email: EmailStr
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True  # Veritabanı modelini JSON'a çevirmeye yarar