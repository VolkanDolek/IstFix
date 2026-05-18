# tests/test_reports.py
import pytest
import uuid
import io
from PIL import Image
from unittest.mock import patch
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# --- PROJE İÇİ BAĞIMLILIKLAR ---
from app.api.routes.reports import router
from app.core.database import get_db, Base
from app.models.citizen import Citizen
from app.models.report import Report
from app.models.municipality import Municipality
from app.api.deps import get_current_user, get_current_admin

# =====================================================================
# 1. TEST VERİTABANI VE İSTEMCİ YAPILANDIRMASI
# =====================================================================
# DİKKAT: 'password' kısmını kendi yerel PostgreSQL şifrenizle değiştirin!
TEST_DATABASE_URL = "postgresql://postgres:PASSWORD@localhost:5432/istfix_test"

engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    """Gerçek veritabanı bağlantısını ezip test veritabanına (istfix_test) yönlendirir."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

# =====================================================================
# 2. GÜVENLİK VE YETKİLENDİRME (AUTH) EZME İŞLEMLERİ
# =====================================================================
def override_get_current_user():
    """Testler sırasında JWT token oluşturmakla vakit kaybetmemek için standart bir vatandaş oturumu taklit eder."""
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    db.close()
    return user

def override_get_current_admin():
    """Testler sırasında yetkili işlem (status güncelleme) yapabilmek için admin oturumu taklit eder."""
    db = TestingSessionLocal()
    admin = db.query(Citizen).filter(Citizen.emailAddress == "admin@istfix.com").first()
    db.close()
    return admin

# FastAPI uygulamasını test modunda ayağa kaldırıp bağımlılıkları değiştiriyoruz
app = FastAPI()
app.include_router(router, prefix="/api/reports")
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user] = override_get_current_user
app.dependency_overrides[get_current_admin] = override_get_current_admin

client = TestClient(app)

# =====================================================================
# 3. VERİTABANI HAZIRLIĞI VE ÖRNEK VERİ EKLEME (SEEDING)
# =====================================================================
@pytest.fixture(autouse=True)
def setup_database():
    """
    Her test fonksiyonundan önce test veritabanını tamamen temizler ve sıfırdan kurar.
    Testlerin izole çalışabilmesi için sahte belediye, admin ve vatandaş kayıtları oluşturur.
    """
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    
    # Sistemin harita tespiti sonrasında eşleşebileceği örnek bir belediye
    test_belediye = Municipality(
        name="Kadıköy",
        officialEmail="destek@kadikoy.bel.tr"
    )
    db.add(test_belediye)
    
    # Standart vatandaş kaydı
    test_user = Citizen(
        name="Vatandaş Test", 
        emailAddress="vatandas@istfix.com", 
        passwordHash="hash", 
        kvkkAccepted=True,
        isAdmin=False
    )
    db.add(test_user)
    
    # Yetkili (Admin) sistem yöneticisi kaydı
    test_admin = Citizen(
        name="Admin Test", 
        emailAddress="admin@istfix.com", 
        passwordHash="hash", 
        kvkkAccepted=True,
        isAdmin=True
    )
    db.add(test_admin)
    
    db.commit()
    db.close()
    
    yield # Testin çalışmasını bekle
    
    # Test bitiminde arta kalan çöpleri temizle
    Base.metadata.drop_all(bind=engine)

# =====================================================================
# 4. YARDIMCI ARAÇLAR
# =====================================================================
def generate_test_image():
    """Disk üzerinde dosya yaratmadan RAM üzerinde anında küçük bir test JPEG'i oluşturur."""
    file = io.BytesIO()
    image = Image.new('RGB', (100, 100), color='red')
    image.save(file, 'jpeg')
    file.seek(0)
    return file

# =====================================================================
# 5. ENTEGRASYON TEST SENARYOLARI (INTEGRATION TESTS)
# =====================================================================

@patch("app.api.routes.reports.analyze_image_with_yolo")
@patch("app.api.routes.reports.generate_complaint_text")
@patch("app.api.routes.reports.get_municipality_from_coords")
@patch("app.api.routes.reports.send_complaint_email")
def test_create_report_success(mock_mail, mock_geo, mock_gemini, mock_yolo):
    """
    Şikayet oluşturma sürecinin (Dosya işleme, Paralel AI çalıştırma, Belediye bulma ve Mail atma)
    bütünsel olarak başarılı çalışıp çalışmadığını test eder. Dış servisler izole edilmiştir (Mock).
    """
    # 1. Hazırlık: Dış servislerin vereceği "sahte" (mock) cevapları yapılandırıyoruz
    mock_yolo.return_value = {"categoryLabel": "Yol Sorunu (Çukur)", "confidenceScore": 0.95}
    mock_gemini.return_value = "Kadıköy'deki çukurun ivedilikle kapatılmasını arz ederim."
    mock_geo.return_value = "Kadıköy"  # Veritabanına eklediğimiz belediye ismiyle eşleşmeli
    mock_mail.return_value = True

    # 2. Aksiyon: FastAPI TestClient ile multipart/form-data tipinde istek atıyoruz
    response = client.post(
        "/api/reports/upload",
        data={
            "latitude": 40.99,
            "longitude": 29.02,
        },
        files={"image": ("test_resim.jpg", generate_test_image(), "image/jpeg")}
    )

    # 3. Doğrulama: Pydantic şemasına göre sanal 'classification' objesinden verileri okuyoruz
    assert response.status_code == 200
    data = response.json()
    
    assert data["classification"]["categoryLabel"] == "Yol Sorunu (Çukur)"
    assert data["classification"]["confidenceScore"] == 0.95
    assert data["processingStatus"] == "EmailDelivered" 
    assert data["isDescriptionAiGenerated"] is True 
    assert "Kadıköy" in data["writtenDescription"]
    
    # Tüm mocklanan servislerin test akışı içinde gerçekten tetiklendiğinden emin ol
    mock_yolo.assert_called_once()
    mock_geo.assert_called_once()
    mock_mail.assert_called_once()

def test_get_my_reports_isolation():
    """
    Bireysel veri gizliliği (Data Isolation) testi:
    Sıradan bir vatandaşın sadece kendi oluşturduğu raporları görebildiğini test eder.
    """
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    
    # Arka planda veritabanına bu kullanıcıya ait bir rapor ekliyoruz.
    # Not: Pydantic şemasında 'photoUrl' zorunlu olduğu için dummy_path.jpg veriyoruz.
    rapor = Report(
        CITIZENId=user.id, 
        categoryLabel="Çöp", 
        confidenceScore=0.9, 
        latitude=0.0, 
        longitude=0.0,
        photoUrl="dummy_path.jpg" 
    )
    db.add(rapor)
    db.commit()
    db.close()

    response = client.get("/api/reports/me")
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    # Pydantic şemasındaki 'classification' objesinden doğruluğunu kontrol et
    assert data[0]["classification"]["categoryLabel"] == "Çöp"

def test_admin_update_report_status():
    """
    Yetki Testi: 
    Admin yetkisine sahip bir kullanıcının, gelen bir şikayetin statüsünü 
    (örneğin 'Pending' konumundan 'Resolved' konumuna) başarıyla güncelleyebildiğini test eder.
    """
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    
    # Manuel test raporu oluşturuyoruz
    rapor = Report(
        CITIZENId=user.id, 
        processingStatus="Pending", 
        categoryLabel="Lamba", 
        confidenceScore=0.9, 
        latitude=0.0, 
        longitude=0.0,
        photoUrl="dummy_path.jpg"
    )
    db.add(rapor)
    db.commit()
    rapor_id = rapor.id
    db.close()

    # Admin kimliğiyle status güncelleme (PATCH) isteği atıyoruz
    response = client.patch(
        f"/api/reports/{rapor_id}/status",
        json={"status": "Resolved"}
    )
    
    assert response.status_code == 200
    assert response.json()["processingStatus"] == "Resolved"