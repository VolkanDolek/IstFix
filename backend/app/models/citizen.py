# backend/app/models/citizen.py
import uuid
from sqlalchemy import Column, String, Boolean, DateTime, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.core.database import Base

class Citizen(Base):
    __tablename__ = "citizens"

    # ER Diyagramındaki alanlar
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    emailAddress = Column(String(255), unique=True, index=True, nullable=False)
    passwordHash = Column(String(255), nullable=False)
    # GÜNCELLEME: utcnow() yerine modern timezone-aware datetime kullanıldı. 
    # (lambda kullanarak fonksiyonu referans veriyoruz):
    registrationDate = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    isActive = Column(Boolean, default=True)
    isAdmin = Column(Boolean, default=False)

    # --- ŞİFRE SIFIRLAMA İÇİN ---
    resetCode = Column(String(4), nullable=True) # 4 haneli doğrulama kodu
    resetCodeExpiresAt = Column(DateTime, nullable=True) # Kodun son geçerlilik tarihi

    # --- BRUTE-FORCE KORUMASI İÇİN ---
    failedLoginAttempts = Column(Integer, default=0) # Hatalı deneme sayısı
    lockoutUntil = Column(DateTime, nullable=True)   # Kilit bitiş zamanı

    # --- KVKK ONAYI İÇİN ---
    kvkkAccepted = Column(Boolean, default=False, nullable=False) 
    kvkkAcceptedAt = Column(DateTime, nullable=True) # Ne zaman onaylandığının damgası

    # GÜNCELLEME: SOFT DELETE / LOGIN BLOKESİ İÇİN AKTİFLİK DURUMU
    isActive = Column(Boolean, default=True) # Silinen kullanıcılar için False yapılır

    # Raporlarla olan ters bağlantı
    reports = relationship("Report", back_populates="citizen")