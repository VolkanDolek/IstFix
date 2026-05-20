# tests/test_security_permissions.py
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import Base, engine, SessionLocal
from app.models.citizen import Citizen
from app.core.security import get_password_hash

client = TestClient(app)

# =====================================================================
# GÜVENLİK TESTİ VERİTABANI HAZIRLIĞI
# =====================================================================

@pytest.fixture(scope="module", autouse=True)
def setup_security_db():
    """
    Bu testte güvenlik kapılarını (Auth) gerçekten zorlayacağımız için
    önceki testlerden kalma 'override' (hileli giriş) ayarlarını temizliyoruz.
    """
    app.dependency_overrides.clear()
    
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    try:
        # 1. Normal Vatandaş (Kötü Niyetli Aktör)
        normal_user = Citizen(
            id=uuid.uuid4(),
            name="Sıradan Vatandaş",
            emailAddress="siradan@istfix.com",
            passwordHash=get_password_hash("Vatandas123!"),
            kvkkAccepted=True,
            isAdmin=False # DİKKAT: Admin değil!
        )
        
        # 2. Yetkili Admin (Hedef)
        admin_user = Citizen(
            id=uuid.uuid4(),
            name="Sistem Admini",
            emailAddress="yetkili@istfix.com",
            passwordHash=get_password_hash("Admin123!"),
            kvkkAccepted=True,
            isAdmin=True
        )
        
        db.add(normal_user)
        db.add(admin_user)
        db.commit()
        db.refresh(admin_user)
        
        # Hedef adminin ID'sini testte kullanmak üzere paylaşıyoruz
        pytest.admin_id = str(admin_user.id) 
        
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

# =====================================================================
# SENARYO: YETKİ İHLALİ (403 FORBIDDEN) TESTİ
# =====================================================================

def test_authorization_403_forbidden_for_normal_user():
    """
    Gereksinim: FR-A2 / FR-A3 (Admin Yetkilendirmesi)
    Açıklama: Normal bir vatandaş (isAdmin=False), kendi geçerli token'ı ile 
              Admin yetkisi gerektiren bir endpoint'e (örneğin hesabı silmeye) 
              istek attığında sistemin işlemi reddedip 403 Forbidden dönmesi gerekir.
    """
    # 1. Normal vatandaş olarak gerçek giriş yap ve JWT Token al
    login_res = client.post(
        "/api/auth/login", 
        data={"username": "siradan@istfix.com", "password": "Vatandas123!"}
    )
    assert login_res.status_code == 200, "Vatandaş girişi başarısız oldu."
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. YETKİSİZ İŞLEM DENEMESİ: Kötü niyetli vatandaşın, Admin'in (veya başkasının) hesabını silmeye çalışması!
    response = client.delete(f"/api/citizens/{pytest.admin_id}", headers=headers)
    
    # 3. Doğrulama: FastAPI, veritabanına bile inmeden kapıdan (Depends) 403 ile kovmalı
    print(f"\n[SECURITY] Yetkisiz işlem denemesi. Sistem yanıtı: HTTP {response.status_code}")
    assert response.status_code == 403, "Güvenlik açığı! Sistem yetkisiz işleme izin verdi."
    
    detail = response.json().get("detail", "").lower()
    # Hata mesajının içeriğini kontrol et (FastAPI genelde "Not authenticated" veya "Forbidden" gibi mesajlar döner)
    assert "yetki" in detail or "privilege" in detail or "forbidden" in detail or "not enough" in detail, "Hata mesajı yetki ihlalini açıklamıyor."