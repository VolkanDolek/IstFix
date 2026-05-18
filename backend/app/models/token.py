#backend/app/models/token.py
from sqlalchemy import Column, String, DateTime
from app.core.database import Base
from datetime import datetime, timezone

class BlacklistedToken(Base):
    __tablename__ = "blacklisted_tokens"
    
    token = Column(String, primary_key=True, index=True)
    # GÜNCELLEME: utcnow() yerine modern timezone-aware datetime kullanıldı. 
    # Lambda fonksiyonu ile her eklenen token için güncel zamanı alır. 
    blacklistedAt = Column(DateTime, default=lambda: datetime.now(timezone.utc))