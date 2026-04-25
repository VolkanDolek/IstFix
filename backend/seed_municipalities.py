import sys
import os
from sqlalchemy import inspect
from sqlalchemy.orm import configure_mappers

# Uygulama dizini
sys.path.append(os.path.join(os.path.dirname(__file__)))

from app.core.database import SessionLocal
# ÖNCE Report ve Citizen, SONRA Municipality
from app.models.citizen import Citizen
from app.models.report import Report
from app.models.municipality import Municipality

def seed_data():
    # SQLAlchemy'yi tüm modelleri taramaya zorla
    configure_mappers()
    
    db = SessionLocal()
    test_email = "test1@gmail.com"
    sile_email = "test2@gmail.com"
    
    municipalities_to_add = [
        {"name": "Beşiktaş", "email": test_email},
        {"name": "Şile", "email": sile_email},
        {"name": "Kadıköy", "email": test_email},
        {"name": "Fatih", "email": test_email},
        {"name": "Üsküdar", "email": test_email},
        {"name": "Beyoğlu", "email": test_email},
        {"name": "Sarıyer", "email": test_email}
    ]

    print(f"--- Belediye Verileri Ekleniyor  ---")

    try:
        for m_data in municipalities_to_add:
            exists = db.query(Municipality).filter(Municipality.name == m_data["name"]).first()
            
            if not exists:
                new_m = Municipality(name=m_data["name"], officialEmail=m_data["email"])
                db.add(new_m)
                print(f"✅ Eklendi: {m_data['name']}")
            else:
                exists.officialEmail = m_data["email"]
                print(f"ℹ️ Güncellendi: {m_data['name']}")

        db.commit()
        print("--- İşlem Başarıyla Tamamlandı ---")
    except Exception as e:
        db.rollback()
        print(f"❌ HATA: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_data()