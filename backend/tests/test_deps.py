# tests/test_deps.py
import pytest
import uuid
from fastapi import FastAPI, Depends
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# --- PROJE İÇİ BAĞIMLILIKLAR ---
from app.api.deps import get_current_user, get_current_admin
from app.core.database import get_db, Base
from app.models.citizen import Citizen
# SQLAlchemy ilişki (Relationship) hatalarını engellemek için diğer modelleri de tanıtıyoruz:
from app.models.report import Report
from app.models.municipality import Municipality
from app.models.token import BlacklistedToken
from app.core.security import create_access_token, get_password_hash

# =====================================================================
# 1. TEST VERİTABANI VE İSTEMCİ YAPILANDIRMASI
# =====================================================================
# DİKKAT: 'password' kısmını kendi yerel PostgreSQL şifrenizle değiştirin!
TEST_DATABASE_URL = "postgresql://postgres:PASSWORD@localhost:5432/istfix_test"

engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

# =====================================================================
# 2. TEST İÇİN SAHTE (DUMMY) FASTAPI UYGULAMASI VE ROTALARI
# =====================================================================
# deps.py kendi başına rota barındırmadığı için, onu test edebileceğimiz 
# mini bir FastAPI uygulamasını sadece bu dosya için ayağa kaldırıyoruz.
app = FastAPI()
app.dependency_overrides[get_db] = override_get_db

@app.get("/protected-user-route")
def dummy_user_route(user: Citizen = Depends(get_current_user)):
    """Sadece geçerli Token'ı olanların girebileceği sahte rota"""
    return {"message": "Giriş Başarılı", "user_id": str(user.id)}

@app.get("/protected-admin-route")
def dummy_admin_route(admin: Citizen = Depends(get_current_admin)):
    """Sadece Admin olanların girebileceği sahte rota"""
    return {"message": "Admin Girişi Başarılı", "admin_id": str(admin.id)}

client = TestClient(app)

# =====================================================================
# 3. VERİTABANI HAZIRLIĞI (SEEDING)
# =====================================================================
@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    
    # 1. Normal Vatandaş
    normal_user = Citizen(
        id=uuid.uuid4(),
        name="Normal Vatandaş", 
        emailAddress="user@istfix.com", 
        passwordHash=get_password_hash("test1234"),
        kvkkAccepted=True,
        isAdmin=False
    )
    
    # 2. Yetkili Admin
    admin_user = Citizen(
        id=uuid.uuid4(),
        name="Admin Kullanıcı", 
        emailAddress="admin@istfix.com", 
        passwordHash=get_password_hash("admin1234"),
        kvkkAccepted=True,
        isAdmin=True
    )
    
    db.add_all([normal_user, admin_user])
    db.commit()
    db.close()
    
    yield
    
    Base.metadata.drop_all(bind=engine)


# =====================================================================
# 4. ENTEGRASYON TEST SENARYOLARI (DEPENDENCY TESTS)
# =====================================================================

def test_get_current_user_success():
    """Geçerli bir JWT Token ile korumalı rotaya erişilebildiğini doğrular."""
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "user@istfix.com").first()
    
    # Test için gerçek bir token üretiyoruz
    valid_token = create_access_token(subject=str(user.id))
    db.close()

    # İstek atarken Header'a Token'ı ekliyoruz
    response = client.get(
        "/protected-user-route", 
        headers={"Authorization": f"Bearer {valid_token}"}
    )
    
    assert response.status_code == 200
    assert "Giriş Başarılı" in response.json()["message"]


def test_get_current_user_blacklisted_token():
    """Kara listeye alınmış (Logout yapılmış) bir token ile giriş yapılamayacağını doğrular."""
    db = TestingSessionLocal()
    user = db.query(Citizen).filter(Citizen.emailAddress == "user@istfix.com").first()
    
    # Token üretip direkt kara listeye (BlacklistedToken) ekliyoruz
    blacklisted_token = create_access_token(subject=str(user.id))
    db.add(BlacklistedToken(token=blacklisted_token))
    db.commit()
    db.close()

    response = client.get(
        "/protected-user-route", 
        headers={"Authorization": f"Bearer {blacklisted_token}"}
    )
    
    assert response.status_code == 401
    assert "Oturumunuz sonlandırılmış" in response.json()["detail"]


def test_get_current_user_invalid_jwt():
    """Bozuk veya sahte bir JWT token gönderildiğinde sistemin 401 döndüğünü doğrular."""
    fake_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sahte_payload.sahte_imza"
    
    response = client.get(
        "/protected-user-route", 
        headers={"Authorization": f"Bearer {fake_token}"}
    )
    
    assert response.status_code == 401
    assert "Kimlik bilgileri doğrulanamadı" in response.json()["detail"]


def test_get_current_user_not_found_in_db():
    """Token geçerli olsa bile (imzası doğru), o UUID'ye sahip kullanıcı DB'den silinmişse 404 döneceğini doğrular."""
    # Veritabanında olmayan rastgele bir UUID ile token üretiyoruz
    ghost_id = str(uuid.uuid4())
    ghost_token = create_access_token(subject=ghost_id)

    response = client.get(
        "/protected-user-route", 
        headers={"Authorization": f"Bearer {ghost_token}"}
    )
    
    assert response.status_code == 404
    assert "Kullanıcı bulunamadı" in response.json()["detail"]


def test_get_current_admin_success():
    """Admin yetkisine sahip kullanıcının özel rotaya erişebildiğini doğrular."""
    db = TestingSessionLocal()
    admin = db.query(Citizen).filter(Citizen.emailAddress == "admin@istfix.com").first()
    admin_token = create_access_token(subject=str(admin.id))
    db.close()

    response = client.get(
        "/protected-admin-route", 
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    
    assert response.status_code == 200
    assert "Admin Girişi Başarılı" in response.json()["message"]


def test_get_current_admin_forbidden():
    """Sıradan bir vatandaşın Admin rotasına girmeye çalıştığında 403 Forbidden yediğini doğrular."""
    db = TestingSessionLocal()
    normal_user = db.query(Citizen).filter(Citizen.emailAddress == "user@istfix.com").first()
    normal_token = create_access_token(subject=str(normal_user.id))
    db.close()

    # Normal kullanıcının token'ı ile admin rotasına istek atıyoruz
    response = client.get(
        "/protected-admin-route", 
        headers={"Authorization": f"Bearer {normal_token}"}
    )
    
    assert response.status_code == 403
    assert "yönetici yetkisi gereklidir" in response.json()["detail"]