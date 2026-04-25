#backend/app/models/token.py
from sqlalchemy import Column, String, DateTime
from app.core.database import Base
from datetime import datetime

class BlacklistedToken(Base):
    __tablename__ = "blacklisted_tokens"
    
    token = Column(String, primary_key=True, index=True)
    blacklistedAt = Column(DateTime, default=datetime.utcnow)