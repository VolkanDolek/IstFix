# backend/app/schemas/citizen_schema.py
from pydantic import BaseModel, EmailStr
from uuid import UUID
from datetime import datetime

# Flutter'dan Kayıt Olurken Gelecek Veri (Giriş)
class CitizenCreate(BaseModel):
    name: str
    emailAddress: EmailStr
    password: str

# API'den Flutter'a Dönecek Veri (Çıkış - Şifre Yok!)
class CitizenResponse(BaseModel):
    id: UUID
    name: str
    emailAddress: EmailStr
    registrationDate: datetime
    isActive: bool

    class Config:
        from_attributes = True  # Veritabanı modelini JSON'a çevirmeye yarar