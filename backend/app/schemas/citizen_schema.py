# backend/app/schemas/citizen_schema.py
from pydantic import BaseModel, EmailStr, ConfigDict
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
    isAdmin: bool

# --- ŞİFRE İŞLEMLERİ İÇİN ---
# 1. Şifremi Unuttum - Kod İsteme (Sadece Email)
class ForgotPasswordRequest(BaseModel):
    email: EmailStr

# 2. Şifre Sıfırlama - Kod ve Yeni Şifre
class ResetPasswordConfirm(BaseModel):
    email: EmailStr
    code: str
    newPassword: str

# 3. Profil İçinden Direkt Değiştirme (Eski Şifre Şart!)
class ChangePasswordRequest(BaseModel):
    oldPassword: str
    newPassword: str

    # Yeni kullanım: Pydantic v2 standardı
    model_config = ConfigDict(from_attributes=True)