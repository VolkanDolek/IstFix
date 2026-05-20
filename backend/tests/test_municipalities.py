# tests/test_municipalities.py
import pytest
import uuid
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# --- PROJE İÇİ BAĞIMLILIKLAR ---
from app.api.routes.municipalities import router
from app.core.database import get_db, Base
from app.models.citizen import Citizen
from app.models.municipality import Municipality
from app.models.report import Report  # SQLAlchemy ilişki hatasını önlemek için şart
from app.api.deps import get_current_admin

# =====================================================================
# 1. TEST VERİTABANI VE İSTEMCİ YAPILANDIRMASI
# =====================================================================
# DİKKAT: 'password' kısmını kendi yerel PostgreSQL şifrenizle değiştirin!
TEST_DATABASE_URL = "postgresql://postgres:PASSWORD@localhost:5432/istfix_test"

engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    """Gerçek DB bağlantısını ezip test veritabanına yönlendirir."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

# =====================================================================
# 2. GÜVENLİK VE YETKİLENDİRME (AUTH) EZME İŞLEMLERİ
# =====================================================================
def override_get_current_admin():
    """Tüm belediye işlemleri sadece adminler tarafından yapılabildiği için, sahte bir admin taklit ediyoruz."""
    db = TestingSessionLocal()
    admin = db.query(Citizen).filter(Citizen.emailAddress == "admin@istfix.com").first()
    db.close()
    return admin

app = FastAPI()
app.include_router(router, prefix="/api/municipalities")
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_admin] = override_get_current_admin

client = TestClient(app)

# =====================================================================
# 3. VERİTABANI HAZIRLIĞI (SEEDING)
# =====================================================================
@pytest.fixture(autouse=True)
def setup_database():
    """Her testten önce test tablolarını sıfırlar ve admin hesabını yaratır."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    
    # Testleri geçebilmek için yetkili bir (Admin) sistem yöneticisi kaydı
    test_admin = Citizen(
        name="Admin Test", 
        emailAddress="admin@istfix.com", 
        passwordHash="hash123!", 
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

def test_add_new_municipality_success():
    """
    Geçerli verilerle yeni bir belediyenin sisteme başarıyla (HTTP 201) 
    eklenip eklenmediğini test eder.
    """
    response = client.post(
        "/api/municipalities/",
        json={
            "name": "Şile",
            "officialEmail": "bilgi@sile.bel.tr"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    assert "id" in data
    assert data["name"] == "Şile"
    assert data["officialEmail"] == "bilgi@sile.bel.tr"

def test_add_new_municipality_duplicate_conflict():
    """
    Benzersizlik (Unique) Kısıtlaması Testi:
    Daha önce eklenmiş bir belediyenin aynı isimle tekrar eklenmeye çalışıldığında, 
    sistemin bunu fark edip HTTP 409 Conflict döndürdüğünü doğrular.
    """
    # İlk kayıt işlemi
    client.post(
        "/api/municipalities/",
        json={"name": "Kadıköy", "officialEmail": "iletisim@kadikoy.bel.tr"}
    )
    
    # Birebir aynı isimle ikinci kez kayıt denemesi
    response = client.post(
        "/api/municipalities/",
        json={"name": "Kadıköy", "officialEmail": "baska@kadikoy.bel.tr"}
    )
    
    assert response.status_code == 409
    assert "zaten sisteme kayıtlı" in response.json()["detail"]

def test_get_all_municipalities():
    """
    Sisteme kayıtlı tüm belediyelerin liste (array) formatında başarıyla 
    getirilebildiğini (HTTP 200) test eder.
    """
    # Arka arkaya iki farklı belediye ekleyelim
    client.post("/api/municipalities/", json={"name": "Şile", "officialEmail": "bilgi@sile.bel.tr"})
    client.post("/api/municipalities/", json={"name": "Üsküdar", "officialEmail": "info@uskudar.bel.tr"})
    
    # Tüm belediyeleri çekelim
    response = client.get("/api/municipalities/")
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["name"] == "Şile"
    assert data[1]["name"] == "Üsküdar"

def test_update_municipality_success():
    """
    Sistemdeki mevcut bir belediyenin bilgilerinin (örn: e-posta adresinin)
    kısmi olarak (PATCH) başarıyla güncellenebildiğini test eder.
    """
    # Önce bir belediye oluşturalım
    create_res = client.post(
        "/api/municipalities/",
        json={"name": "Beşiktaş", "officialEmail": "eski@besiktas.bel.tr"}
    )
    muni_id = create_res.json()["id"]
    
    # Sadece e-posta adresini güncelleyelim
    update_res = client.patch(
        f"/api/municipalities/{muni_id}",
        json={"officialEmail": "yeni@besiktas.bel.tr"}
    )
    
    assert update_res.status_code == 200
    data = update_res.json()
    assert data["id"] == muni_id
    # E-posta değişmiş olmalı
    assert data["officialEmail"] == "yeni@besiktas.bel.tr"
    # İsim aynı kalmalı
    assert data["name"] == "Beşiktaş"

def test_update_municipality_not_found():
    """
    Veritabanında olmayan rastgele bir belediye ID'si güncellenmek istendiğinde
    sistemin çökmeden zarif bir şekilde HTTP 404 (Bulunamadı) döndüğünü test eder.
    """
    fake_uuid = str(uuid.uuid4())
    response = client.patch(
        f"/api/municipalities/{fake_uuid}",
        json={"name": "Olmayan"}
    )
    
    assert response.status_code == 404
    assert "bulunamadı" in response.json()["detail"].lower()