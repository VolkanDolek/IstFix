# backend/app/models/report.py
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.sql import func
from geoalchemy2 import Geometry # PostGIS için özel kütüphanemiz
from app.core.database import Base

class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id")) # Hangi kullanıcı gönderdi?
    
    category = Column(String, index=True) # Örn: road_damage, broken_streetlight
    description = Column(String) # Gemini'nin oluşturduğu resmi şikayet metni
    image_url = Column(String) # Fotoğrafın sunucudaki konumu
    
    # PostGIS ile Coğrafi Nokta (Point) - SRID 4326 (Standart GPS)
    location = Column(Geometry(geometry_type='POINT', srid=4326))
    
    municipality = Column(String) # Örn: "Kadikoy Belediyesi"
    status = Column(String, default="pending") # pending (bekliyor), resolved (çözüldü)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())