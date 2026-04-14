# backend/app/core/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

# Veritabanı motorunu çalıştır
engine = create_engine(settings.DATABASE_URL)

# Veritabanı ile konuşacak oturum yapısı
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# İleride oluşturacağımız tabloların (User, Report) miras alacağı temel sınıf
Base = declarative_base()

# Veritabanı bağlantısını alıp işi bitince kapatan güvenlik fonksiyonu
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
