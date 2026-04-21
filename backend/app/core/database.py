# backend/app/core/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.core.config import settings

# 1. Veritabanı motorunu çalıştır
# PostgreSQL bağlantısı için settings.DATABASE_URL
engine = create_engine(
    settings.DATABASE_URL,
    # PostgreSQL için bağlantı havuzu ayarları (opsiyonel ama önerilir)
    pool_pre_ping=True 
)

# 2. Veritabanı ile konuşacak oturum yapısı
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 3. Modern SQLAlchemy 2.0 Declarative Base yapısı
# Citizen ve Report modelleri bu sınıftan miras alacak.
class Base(DeclarativeBase):
    pass

# 4. Veritabanı bağlantısını alıp işi bitince kapatan güvenlik fonksiyonu
def get_db():
    """
    FastAPI endpoint'lerinde 'Depends(get_db)' olarak kullanılır.
    Her istekte yeni bir oturum açar ve işlem bitince güvenli bir şekilde kapatır.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
