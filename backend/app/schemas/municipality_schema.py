# backend/app/schemas/municipality_schema.py
from pydantic import BaseModel, EmailStr, ConfigDict
from uuid import UUID

# 1. Yeni Belediye Eklerken Kullanılacak (Giriş)
class MunicipalityCreate(BaseModel):
    name: str
    officialEmail: EmailStr

# 2. API'den Dönecek Olan Belediye Verisi (Çıkış)
class MunicipalityResponse(BaseModel):
    id: UUID
    name: str
    officialEmail: EmailStr

    # Yeni kullanım: Pydantic v2 standardı
    model_config = ConfigDict(from_attributes=True)