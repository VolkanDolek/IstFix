# tests/test_api_router.py
from fastapi import FastAPI
from fastapi.testclient import TestClient

# --- PROJE İÇİ BAĞIMLILIKLAR ---
from app.api.api_router import api_router

# Sadece rotaların doğru bağlanıp bağlanmadığını test etmek için 
# veritabanı bağlantısı olmayan, boş ve izole bir FastAPI uygulaması ayağa kaldırıyoruz.
app = FastAPI()
app.include_router(api_router, prefix="/api")

client = TestClient(app)

# =====================================================================
# ENTEGRASYON TEST SENARYOSU (ROUTER MOUNTING TEST)
# =====================================================================

def test_api_router_mounts_all_endpoints():
    """
    api_router.py dosyasının; auth, reports, citizens ve municipalities modüllerini
    doğru prefix (ön ek) ile ana uygulamaya bağlayıp bağlamadığını test eder.
    Bu test, URL çakışmalarını ve unutulan importları anında yakalar.
    """
    # FastAPI uygulamasının hafızasına kazınan tüm rotaları (URL'leri) liste halinde alıyoruz
    registered_routes = [route.path for route in app.routes]

    # 1. Auth (Kimlik Doğrulama) Rotaları Bağlanmış mı?
    assert "/api/auth/login" in registered_routes
    assert "/api/auth/register" in registered_routes

    # 2. Reports (Şikayet) Rotaları Bağlanmış mı?
    assert "/api/reports/upload" in registered_routes
    assert "/api/reports/me" in registered_routes

    # 3. Citizens (Kullanıcı Yönetimi) Rotaları Bağlanmış mı?
    assert "/api/citizens/forgot-password" in registered_routes
    assert "/api/citizens/reset-password" in registered_routes

    # 4. Municipalities (Belediye Yönetimi) Rotaları Bağlanmış mı?
    assert "/api/municipalities/" in registered_routes

def test_openapi_schema_generation():
    """
    Tüm rotalar birleştiğinde FastAPI'nin otomatik oluşturduğu Swagger UI 
    dokümantasyon şemasının çökmeden üretilebildiğini (duman testi) kontrol eder.
    """
    response = client.get("/openapi.json")
    
    assert response.status_code == 200
    openapi_schema = response.json()
    
    # Swagger şemasında tanımlı modüllerin etiketleri (Tags) var mı kontrol edelim
    paths = openapi_schema.get("paths", {})
    
    assert "/api/auth/login" in paths
    assert "/api/reports/upload" in paths
    assert "/api/citizens/" in paths