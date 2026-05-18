# tests/test_main.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

# =====================================================================
# BİRİM VE ENTEGRASYON TESTLERİ (MAIN APP)
# =====================================================================

def test_read_root():
    """
    Uygulamanın ana kapısının (Health Check) açık olduğunu ve 
    doğru JSON yanıtını döndürdüğünü test eder.
    """
    response = client.get("/")
    assert response.status_code == 200
    
    data = response.json()
    assert data["status"] == "online"
    assert data["project"] == "IstFix Backend"
    assert "Başarıyla Çalışıyor" in data["message"]

def test_cors_configuration():
    """
    Mobil (Flutter) veya Web istemcilerinden gelecek olan farklı kökenli (Cross-Origin) 
    isteklere sunucunun güvenlik kuralları çerçevesinde izin verdiğini test eder.
    """
    test_origin = "http://localhost:3000"
    response = client.options(
        "/api/auth/login", # Rastgele bir endpoint
        headers={
            "Origin": test_origin,
            "Access-Control-Request-Method": "POST",
        }
    )
    
    assert response.status_code == 200
    assert "access-control-allow-origin" in response.headers
    # Güvenlik gereği allow_credentials=True olduğunda '*' yerine doğrudan Origin adresi dönülür
    assert response.headers["access-control-allow-origin"] == test_origin

def test_static_files_mounting():
    """
    Fotoğrafların barındırılacağı '/uploads' klasörünün uygulamanın
    rotalarına başarıyla bağlanıp bağlanmadığını test eder.
    """
    routes = [route.path for route in app.routes]
    assert "/uploads" in routes