# backend/app/models/citizen.py
import uuid
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base

class Citizen(Base):
    __tablename__ = "citizens"

    # ER Diyagramındaki alanlar
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    emailAddress = Column(String(255), unique=True, index=True, nullable=False)
    passwordHash = Column(String(255), nullable=False)
    registrationDate = Column(DateTime, default=datetime.utcnow)
    isActive = Column(Boolean, default=True)

    # Raporlarla olan ters bağlantı
    reports = relationship("Report", back_populates="citizen")