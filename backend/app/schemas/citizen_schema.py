# backend/app/schemas/citizen_schema.py
from pydantic import BaseModel, EmailStr, ConfigDict, field_validator
from uuid import UUID
from datetime import datetime

# Flutter'dan Kayıt Olurken Gelecek Veri (Giriş)
class CitizenCreate(BaseModel):
    name: str
    emailAddress: EmailStr
    password: str
    kvkkAccepted: bool

    # Pydantic V2 yapısına uygun doğrulama: True olmak zorunda
    @field_validator('kvkkAccepted')
    @classmethod
    def check_kvkk(cls, v):
        if not v:
            raise ValueError("Kayıt olabilmek için KVKK Aydınlatma Metni'ni onaylamanız gerekmektedir.")
        return v

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

# 2a. Şifre Sıfırlama - Kod ve Yeni Şifre
class ResetPasswordConfirm(BaseModel):
    email: EmailStr
    code: str
    newPassword: str

# 2b. Şifre Sıfırlama - Kod Doğrulama (Yeni Şifre Yok, Sadece Kod Doğrulama)
class VerifyCodeRequest(BaseModel):
    email: EmailStr
    code: str

# 3. Profil İçinden Direkt Değiştirme (Eski Şifre Şart!)
class ChangePasswordRequest(BaseModel):
    oldPassword: str
    newPassword: str

    # Yeni kullanım: Pydantic v2 standardı
    model_config = ConfigDict(from_attributes=True)