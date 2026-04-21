# backend/app/models/report.py
import uuid
from sqlalchemy import Column, String, Float, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from geoalchemy2 import Geometry
from datetime import datetime
from app.core.database import Base

class Report(Base):
    __tablename__ = "reports"

    # 1. UUID Anahtarlar
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    CITIZENId = Column(UUID(as_uuid=True), ForeignKey("citizens.id"), nullable=False)
    
    # İleride Municipality tablosunu oluşturunca bunu aktif edeceğiz:
    # MUNICIPALITYId = Column(UUID(as_uuid=True), ForeignKey("municipalities.id"), nullable=True) 

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
    submissionTimestamp = Column(DateTime, default=datetime.utcnow)
    processingStatus = Column(String(20), default="Pending") # Pending, Classifying, vb.