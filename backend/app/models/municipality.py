# backend/app/models/municipality.py
import uuid
from sqlalchemy import Column, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base


class Municipality(Base):
    __tablename__ = "municipalities"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, unique=True, nullable=False) # Örn: "Şile Belediyesi"
    officialEmail = Column(String, nullable=False)     # Örn: "bilgi@sile.bel.tr"

    # İlişki: Bir belediyeye birçok rapor gelebilir
    reports = relationship("Report", back_populates="municipality")

    def __repr__(self):
        return f"<Municipality(name={self.name}, email={self.officialEmail})>"