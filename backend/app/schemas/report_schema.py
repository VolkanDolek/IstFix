# backend/app/schemas/report_schema.py
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# Flutter'dan Şikayet Gönderirken Gelecek Veri
class ReportCreate(BaseModel):
    category: str
    latitude: float   # Enlem (Örn: 41.0082)
    longitude: float  # Boylam (Örn: 28.9784)
    # Fotoğrafı ayrı bir dosya (UploadFile) olarak alacağımız için buraya koymuyoruz

# API'den Flutter'a (Harita Ekranına) Dönecek Şikayet Verisi
class ReportResponse(BaseModel):
    id: int
    user_id: int
    category: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    municipality: Optional[str] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True