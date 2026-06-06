# backend/app/models/report.py
import uuid
from sqlalchemy import Column, String, Float, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship # İlişkiler için
from geoalchemy2 import Geometry
from datetime import datetime, timezone
from app.core.database import Base

class Report(Base):
    __tablename__ = "reports"

    # 1. UUID Anahtarlar
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    CITIZENId = Column(UUID(as_uuid=True), ForeignKey("citizens.id"), nullable=False)
    
    # Municipality tablosu artık hazır olduğu için burası aktif
    MUNICIPALITYId = Column(UUID(as_uuid=True), ForeignKey("municipalities.id"), nullable=True) 

    # 2. Medya ve Metin
    photoUrl = Column(String(500))
    writtenDescription = Column(Text, nullable=True)
    isDescriptionAiGenerated = Column(Boolean, default=True)
    
    # 3. Konum (ER Diyagramına göre Lat/Lon ayrı tutuluyor)
    latitude = Column(Float)
    longitude = Column(Float)
    
    # (Opsiyonel) PostGIS hesaplamaları için GeoAlchemy kolonunu koruyabiliriz
    # Veritabanında coğrafi indexleme yapmak istersek bu işe yarayacak
    geom = Column(Geometry(geometry_type='POINT', srid=4326), nullable=True)

    # 4. Zaman ve Durum
    # GÜNCELLEME: utcnow() yerine modern timezone-aware datetime kullanıldı
    submissionTimestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    processingStatus = Column(String(20), default="Pending") # Pending, InProgress, vb.

    # GÜNCELLEME: SOFT DELETE BAYRAĞI
    isArchived = Column(Boolean, default=False) # True olduğunda sistemden gizlenir
    
    # --- AI Analiz Sonuçlarını Saklayacak Kolonlar ---
    categoryLabel = Column(String(100), nullable=True)
    confidenceScore = Column(Float, nullable=True)

    # Pydantic Şeması İçin Sanal Köprü
    # Bu özellik, şemadaki 'classification' alanı ile veritabanındaki 
    # 'categoryLabel' ve 'confidenceScore' arasında otomatik bağ kurar.
    @property
    def classification(self):
        if self.categoryLabel:
            return {
                "categoryLabel": self.categoryLabel,
                "confidenceScore": self.confidenceScore
            }
        return None

    # --- İLİŞKİLER (RELATIONSHIPS) ---
    # Bu kısımlar SQLAlchemy üzerinden nesnelere kolay erişim sağlar
    citizen = relationship("Citizen", back_populates="reports")
    municipality = relationship("Municipality", back_populates="reports", foreign_keys=[MUNICIPALITYId])