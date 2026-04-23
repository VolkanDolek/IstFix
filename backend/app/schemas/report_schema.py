# backend/app/schemas/report_schema.py
from pydantic import BaseModel, ConfigDict, field_validator
from datetime import datetime
from typing import Optional
from app.schemas.municipality_schema import MunicipalityResponse
from uuid import UUID

# 1. YOLOv8 Analiz Sonuçları İçin Alt Şema (ER: ISSUE_CLASSIFICATION tablosu)
class IssueClassificationResponse(BaseModel):
    categoryLabel: str
    confidenceScore: float
    
    model_config = ConfigDict(from_attributes=True)

# 2. Mobil Uygulamadan Rapor Gönderilirken Gelecek Veri (Kategori yok, AI bulacak)
class ReportCreate(BaseModel):
    latitude: float
    longitude: float
    writtenDescription: Optional[str] = None

# 3. API'den Haritaya Dönecek Olan Rapor Verisi
class ReportResponse(BaseModel):
    id: UUID
    CITIZENId: UUID
    MUNICIPALITYId: Optional[UUID] = None
    
    photoUrl: str
    latitude: float
    longitude: float
    
    writtenDescription: Optional[str] = None
    isDescriptionAiGenerated: bool
    submissionTimestamp: datetime
    processingStatus: str
    
    # Raporun hangi belediyeye ait olduğu obje olarak döner
    municipality: Optional[MunicipalityResponse] = None

    # Kategori bilgisini ilişkili tablodan (ISSUE_CLASSIFICATION) otomatik çekecek yapı:
    classification: Optional[IssueClassificationResponse] = None

    # --- URL DÖNÜŞTÜRÜCÜ ---
    @field_validator("photoUrl")
    @classmethod
    def convert_path_to_url(cls, v: str) -> str:
        if not v:
            return v
        if v.startswith("http"):
            return v
        
        # KRİTİK: Buraya bilgisayarın yerel IP adresi yazılmalı.
        # Terminale 'ipconfig' yazarak IPv4 adresi bulunabilir. (Örn: "http://192.168.1.35:8000")
        # Localde denenecekse "http://localhost:8000" kullanılabilir.
        base_url = "http://localhost:8000" 
        clean_path = v.replace("\\", "/")
        return f"{base_url}/{clean_path}"
    
# 4. Güncelleme Şeması (Belediye Rapor Durumu Güncellemek İstediğinde)
class ReportStatusUpdate(BaseModel):
    status: str

    # Yeni kullanım: Pydantic v2 standardı
    model_config = ConfigDict(from_attributes=True)