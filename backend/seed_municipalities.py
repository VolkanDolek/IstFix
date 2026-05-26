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
        # +1: İstanbul Genel / Büyükşehir
        {"name": "İstanbul Büyükşehir Belediyesi", "email": test_email},
    
        # 39 İlçe Belediyesi
        {"name": "Adalar", "email": test_email},
        {"name": "Arnavutköy", "email": test_email},
        {"name": "Ataşehir", "email": test_email},
        {"name": "Avcılar", "email": test_email},
        {"name": "Bağcılar", "email": test_email},
        {"name": "Bahçelievler", "email": test_email},
        {"name": "Bakırköy", "email": test_email},
        {"name": "Başakşehir", "email": test_email},
        {"name": "Bayrampaşa", "email": test_email},
        {"name": "Beşiktaş", "email": test_email},
        {"name": "Beykoz", "email": test_email},
        {"name": "Beylikdüzü", "email": test_email},
        {"name": "Beyoğlu", "email": test_email},
        {"name": "Büyükçekmece", "email": test_email},
        {"name": "Çatalca", "email": test_email},
        {"name": "Çekmeköy", "email": test_email},
        {"name": "Esenler", "email": test_email},
        {"name": "Esenyurt", "email": test_email},
        {"name": "Eyüpsultan", "email": test_email},
        {"name": "Fatih", "email": test_email},
        {"name": "Gaziosmanpaşa", "email": test_email},
        {"name": "Güngören", "email": test_email},
        {"name": "Kadıköy", "email": test_email},
        {"name": "Kağıthane", "email": test_email},
        {"name": "Kartal", "email": test_email},
        {"name": "Küçükçekmece", "email": test_email},
        {"name": "Maltepe", "email": test_email},
        {"name": "Pendik", "email": test_email},
        {"name": "Sancaktepe", "email": test_email},
        {"name": "Sarıyer", "email": test_email},
        {"name": "Silivri", "email": test_email},
        {"name": "Sultanbeyli", "email": test_email},
        {"name": "Sultangazi", "email": test_email},
        {"name": "Şile", "email": sile_email},  # Şile özel emaili korundu
        {"name": "Şişli", "email": test_email},
        {"name": "Tuzla", "email": test_email},
        {"name": "Ümraniye", "email": test_email},
        {"name": "Üsküdar", "email": test_email},
        {"name": "Zeytinburnu", "email": test_email}
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