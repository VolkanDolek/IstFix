# backend/app/schemas/municipality_schema.py
from pydantic import BaseModel, EmailStr, ConfigDict
from uuid import UUID
from typing import Optional

# 1. Yeni Belediye Eklerken Kullanılacak (Giriş)
class MunicipalityCreate(BaseModel):
    name: str
    officialEmail: EmailStr

# 2. API'den Dönecek Olan Belediye Verisi (Çıkış)
class MunicipalityResponse(BaseModel):
    id: UUID
    name: str
    officialEmail: EmailStr

# 3. Belediye Bilgilerini Güncellemek İçin Kullanılacak (Güncelleme)
class MunicipalityUpdate(BaseModel):
    name: Optional[str] = None
    officialEmail: Optional[EmailStr] = None

    # Yeni kullanım: Pydantic v2 standardı
    model_config = ConfigDict(from_attributes=True)