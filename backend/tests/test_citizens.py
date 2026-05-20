# tests/test_citizens.py
import pytest
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
from fastapi import FastAPI, Depends, status # GÜNCELLEME: status kütüphanesi eklendi
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

# --- PROJE İÇİ BAĞIMLILIKLAR ---
from app.api.routes.citizens import router
from app.core.database import get_db, Base
from app.models.citizen import Citizen
# SQLAlchemy ilişki (Relationship) hatalarını engellemek için diğer modelleri de tanıtıyoruz:
from app.models.report import Report
from app.models.municipality import Municipality
from app.api.deps import get_current_user, get_current_admin
from app.core.security import get_password_hash, verify_password

# =====================================================================
# 1. TEST VERİTABANI VE İSTEMCİ YAPILANDIRMASI
# =====================================================================
# DİKKAT: 'password' kısmını kendi yerel PostgreSQL şifrenizle değiştirin!
TEST_DATABASE_URL = "postgresql://postgres:PASSWORD@localhost:5432/istfix_test"

engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    """Gerçek veritabanı bağlantısını ezip test veritabanına yönlendirir."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

# =====================================================================
# 2. GÜVENLİK VE YETKİLENDİRME (AUTH) EZME İŞLEMLERİ
# =====================================================================
# DİKKAT: Yeni bağlantı açmak yerine rotanın kendi oturumunu (Depends(get_db)) 
# kullanıyoruz. Böylece DetachedInstance ve Deadlock (donma) hatalarını önlüyoruz.
def override_get_current_user(db: Session = Depends(get_db)):
    """FastAPI'nin kendi oturumunu kullanarak test kullanıcısını döndürür."""
    return db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()

def override_get_current_admin(db: Session = Depends(get_db)):
    """FastAPI'nin kendi oturumunu kullanarak admin test kullanıcısını döndürür."""
    return db.query(Citizen).filter(Citizen.emailAddress == "admin@istfix.com").first()

app = FastAPI()
app.include_router(router, prefix="/api/citizens")
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user] = override_get_current_user
app.dependency_overrides[get_current_admin] = override_get_current_admin

client = TestClient(app)

# =====================================================================
# 3. VERİTABANI HAZIRLIĞI (SEEDING)
# =====================================================================
@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    
    test_user = Citizen(
        id=uuid.uuid4(),
        name="Vatandaş Test", 
        emailAddress="vatandas@istfix.com", 
        passwordHash=get_password_hash("eski_sifre123"), # Test 3 için özel şifre 
        kvkkAccepted=True,
        isAdmin=False
    )
    db.add(test_user)
    
    test_admin = Citizen(
        id=uuid.uuid4(),
        name="Admin Test", 
        emailAddress="admin@istfix.com", 
        passwordHash=get_password_hash("admin_sifre123"), 
        kvkkAccepted=True,
        isAdmin=True
    )
    db.add(test_admin)
    db.commit()
    db.close()
    
    yield
    
    Base.metadata.drop_all(bind=engine)

# =====================================================================
# 4. ENTEGRASYON TEST SENARYOLARI (INTEGRATION TESTS)
# =====================================================================

# Test 1: Şifremi Unuttum - Başarılı Kod Gönderimi (Mail servisi mocklandı)
@patch("app.api.routes.citizens.send_otp_email")
def test_forgot_password_success(mock_mail):
    mock_mail.return_value = True
    
    response = client.post(
        "/api/citizens/forgot-password",
        json={"email": "vatandas@istfix.com"}
    )
    
    assert response.status_code == 200
    assert "Sıfırlama kodu" in response.json()["message"]
    mock_mail.assert_called_once()
    
    # Veritabanında kodun gerçekten yaratıldığını doğrula
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    assert user.resetCode is not None
    assert user.resetCodeExpiresAt is not None
    db.close()

# Test 2: Kod ile Şifre Sıfırlama
def test_reset_password_success():
    # Manuel olarak bir kod ve süre atıyoruz
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    user.resetCode = "1234"
    user.resetCodeExpiresAt = datetime.now(timezone.utc) + timedelta(minutes=15)
    db.commit()
    db.close()

    response = client.post(
        "/api/citizens/reset-password",
        json={
            "email": "vatandas@istfix.com",
            "code": "1234",
            "newPassword": "YeniSifre123!"
        }
    )
    
    assert response.status_code == 200
    assert "başarıyla sıfırlandı" in response.json()["message"]

    # Kodun kullanıldıktan sonra temizlendiğini doğrula
    db = TestingSessionLocal()
    updated_user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    assert updated_user.resetCode is None
    assert updated_user.resetCodeExpiresAt is None
    # Yeni şifrenin geçerliliğini test et
    assert verify_password("YeniSifre123!", updated_user.passwordHash) is True
    db.close()

# Test 3: Profil İçinden Şifre Değiştirme
def test_change_password_success():
    response = client.patch(
        "/api/citizens/change-password",
        json={
            "oldPassword": "eski_sifre123",
            "newPassword": "BambaşkaSifre123!"
        }
    )
    
    assert response.status_code == 200
    assert "başarıyla güncellendi" in response.json()["message"]

    db = TestingSessionLocal()
    updated_user = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    assert verify_password("BambaşkaSifre123!", updated_user.passwordHash) is True
    db.close()

# Test 4: Admin Tüm Vatandaşları Listeleme
def test_get_all_citizens_by_admin():
    response = client.get("/api/citizens/")
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2  # Biri Admin, Biri Vatandaş (Setup'tan gelenler)
    assert data[0]["emailAddress"] == "vatandas@istfix.com"

# Test 5: Admin Vatandaş Hesabını Silme (Purge)
def test_delete_citizen_account_by_admin():
    db = TestingSessionLocal()
    user_to_delete = db.query(Citizen).filter(Citizen.emailAddress == "vatandas@istfix.com").first()
    user_id = str(user_to_delete.id)
    db.close()

    response = client.delete(f"/api/citizens/{user_id}")
    
    assert response.status_code == 200
    assert "kalıcı olarak kaldırıldı" in response.json()["message"]

    # Kullanıcının gerçekten silindiğini doğrula
    db = TestingSessionLocal()
    check_user = db.query(Citizen).filter(Citizen.id == user_id).first()
    assert check_user is None
    db.close()

# =====================================================================
# GÜNCELLEME: 5. AKIŞ İÇİN ROL TABANLI KORUMA ENTEGRASYON TESTİ
# =====================================================================
def test_delete_admin_account_by_admin_forbidden():
    """
    Hiyerarşik Yetki Koruma Denetimi:
    Sistem yöneticisi rolündeki bir kullanıcının, başka bir admin hesabını API katmanı 
    üzerinden kalıcı olarak imha etme yetkisinin bloke edildiğini (403 Forbidden) doğrular.
    """
    db = TestingSessionLocal()
    admin_to_delete = db.query(Citizen).filter(Citizen.emailAddress == "admin@istfix.com").first()
    admin_id = str(admin_to_delete.id)
    db.close()

    # Admin oturumu simüle edilerek yine bir admin hesabına silme isteği (DELETE) gönderilir
    response = client.delete(f"/api/citizens/{admin_id}")
    
    # API kalkanı sayesinde işlemin reddedilmesi ve HTTP 403 statüsünün dönmesi denetlenir
    assert response.status_code == status.HTTP_403_FORBIDDEN
    # GÜNCELLEME: citizens.py içerisindeki tam metne ("Sistem yöneticisi (Admin)...") uyum sağlandı
    assert "Sistem yöneticisi (Admin) statüsündeki hesaplar mobil kontrol paneli üzerinden silinemez" in response.json()["detail"]

    # Kritik Hesap Kontrolü: Engelleme sonrasında admin hesabının yerinde durduğu teyit edilir
    db = TestingSessionLocal()
    check_admin = db.query(Citizen).filter(Citizen.id == admin_id).first()
    assert check_admin is not None
    db.close()