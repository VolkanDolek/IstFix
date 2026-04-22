# backend/app/schemas/report_schema.py
from pydantic import BaseModel, ConfigDict
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

    # Yeni kullanım: Pydantic v2 standardı
    model_config = ConfigDict(from_attributes=True)