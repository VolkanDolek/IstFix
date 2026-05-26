# tests/test_auth.py
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Proje içi bağımlılıklar
from app.api.routes.auth import router
from app.core.database import get_db, Base

# SQLAlchemy'nin tüm tabloları ve aralarındaki ilişkileri (relationship) 
# sorunsuz kurabilmesi için tüm modelleri import ediyoruz:
from app.models.citizen import Citizen
from app.models.report import Report
from app.models.municipality import Municipality
from app.models.token import BlacklistedToken

# 1. TEST VERİTABANI BAĞLANTI AYARI
# Kendi yerel PostgreSQL kullanıcı adı ve şifrenize göre burayı düzenle.
# istfix_test adında bir veritabanı
TEST_DATABASE_URL = "postgresql://postgres:PASSWORD@localhost:5432/istfix_test"

# Test motorunu ve oturum yapısını kuruyoruz
engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# FastAPI'nin get_db bağımlılığını (dependency) test veritabanına yönlendiriyoruz
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

# Geçici FastAPI test uygulaması kurulumu
app = FastAPI()
app.include_router(router, prefix="/api/auth")
app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

# 2. SEED & TEARDOWN MEKANİZMASI (Her test çalışmasında veritabanını sıfırlar)
@pytest.fixture(autouse=True)
def setup_database():
    """
    Her test fonksiyonu çalışmadan önce PostgreSQL test veritabanındaki tüm tabloları sıfırlar,
    tabloları temiz bir şekilde yeniden kurar. Test bitince tabloları kaldırır.
    """
    # Önceki testlerden kalan tablolar varsa temizle
    Base.metadata.drop_all(bind=engine)
    # Tabloları PostgreSQL standartlarında (UUID dahil) sıfırdan oluştur
    Base.metadata.create_all(bind=engine)
    yield
    # Test bittikten sonra arkada çöp veri bırakmamak için temizle
    Base.metadata.drop_all(bind=engine)


# --- INTEGRATION (ENTEGRASYON) TEST SENARYOLARI ---

def test_register_success():
    """
    Yeni bir vatandaşın yerel PostgreSQL test veritabanına UUID üreterek 
    başarılı bir şekilde kayıt olup olmadığını (HTTP 201) test eder.
    """
    response = client.post(
        "/api/auth/register",
        json={
            "name": "Ege Demirezen",
            "emailAddress": "ege@istfix.com",
            "password": "SecurePassword123!",
            "kvkkAccepted": True
        }
    )
    assert response.status_code == 201
    data = response.json()
    
    # Doğrulamalar
    assert "id" in data  # PostgreSQL'in UUID üretip üretmediğini kontrol et
    assert data["name"] == "Ege Demirezen"
    assert data["emailAddress"] == "ege@istfix.com"
    assert "password" not in data  # Güvenlik Kontrolü: Hashlenmiş şifre bile arayüze dönmemeli

def test_register_duplicate_email():
    """
    Aynı e-posta adresi ile ikinci kez kayıt olunmaya çalışıldığında 
    PostgreSQL benzersizlik (Unique) kısıtlamasının tetiklenip tetiklenmediğini test eder.
    """
    # İlk kayıt
    client.post(
        "/api/auth/register",
        json={"name": "İlk Kullanıcı", "emailAddress": "ayni@istfix.com", "password": "Pass!", "kvkkAccepted": True}
    )
    
    # Aynı mail ile ikinci kayıt denemesi
    response = client.post(
        "/api/auth/register",
        json={"name": "İkinci Kullanıcı", "emailAddress": "ayni@istfix.com", "password": "NewPass!", "kvkkAccepted": True}
    )
    
    assert response.status_code == 400
    assert "zaten kayıtlı" in response.json()["detail"]

def test_login_success():
    """
    Kullanıcı doğru bilgilerle giriş yaptığında JWT token üretimini 
    ve response içeriğini test eder.
    """
    client.post(
        "/api/auth/register",
        json={"name": "Giriş Test", "emailAddress": "login@istfix.com", "password": "DogruSifre123!", "kvkkAccepted": True}
    )
    
    # OAuth2 şeması form-data veri yapısı bekler
    response = client.post(
        "/api/auth/login",
        data={"username": "login@istfix.com", "password": "DogruSifre123!"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["name"] == "Giriş Test"

def test_login_lockout_mechanism():
    """
    Brute-force koruması: Kullanıcı 5 kez üst üste hatalı şifre girdiğinde
    PostgreSQL üzerindeki sayaçların güncellenip hesabın kilitlendiğini (HTTP 403) doğrular.
    """
    client.post(
        "/api/auth/register",
        json={"name": "Kilit Test", "emailAddress": "bruteforce@istfix.com", "password": "GecerliSifre!", "kvkkAccepted": True}
    )
    
    # 4 kez hatalı deneme yapalım (HTTP 401 dönmeli)
    for _ in range(4):
        res = client.post("/api/auth/login", data={"username": "bruteforce@istfix.com", "password": "YanlisSifre!"})
        assert res.status_code == 401
        
    # 5. ve son hatalı deneme (Hesap kilitlenmeli ve HTTP 403 Forbidden dönmeli)
    res_5th = client.post("/api/auth/login", data={"username": "bruteforce@istfix.com", "password": "YanlisSifre!"})
    assert res_5th.status_code == 403
    assert "kilitlenmiştir" in res_5th.json()["detail"].lower() or "kilitlendi" in res_5th.json()["detail"].lower()

# GÜNCELLEME: SİLİNMİŞ (SOFT DELETE) KULLANICI GİRİŞ KONTROLÜ
def test_login_inactive_user_forbidden():
    """
    Kullanıcı 'Soft Delete' ile silindiyse (isActive=False), şifreyi doğru bilse bile 
    sisteme giriş yapamayacağını doğrular.
    """
    client.post(
        "/api/auth/register",
        json={"name": "Silinmiş Adam", "emailAddress": "silinmis@istfix.com", "password": "DogruSifre123!", "kvkkAccepted": True}
    )
    
    # Arka planda hesabı pasife alıyoruz (Adminin sildiğini simüle ediyoruz)
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "silinmis@istfix.com").first()
    user.isActive = False
    db.commit()
    db.close()

    # Şifre doğru girilse bile 403 dönmeli
    response = client.post(
        "/api/auth/login",
        data={"username": "silinmis@istfix.com", "password": "DogruSifre123!"}
    )
    
    assert response.status_code == 403
    assert "silinmiş veya kullanıma kapatılmıştır" in response.json()["detail"]