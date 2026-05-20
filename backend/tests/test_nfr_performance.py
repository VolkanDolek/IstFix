# tests/test_nfr_performance.py
import time
import pytest
import io
from PIL import Image
from fastapi.testclient import TestClient

# Proje içi bağımlılıklar
from app.main import app
from app.core.database import Base, engine, SessionLocal
from app.models.report import Report
from app.models.municipality import Municipality
from app.models.citizen import Citizen
from app.services.geo_service import get_municipality_from_coords
from app.api.deps import get_current_user

# FastAPI uygulamasını test ortamına (TestClient) bağlıyoruz
client = TestClient(app)

# =====================================================================
# GÜVENLİK BYPASS (AUTHENTICATION OVERRIDE) İŞLEMLERİ
# =====================================================================

def override_get_current_user():
    """
    Test ortamında yetkilendirme (OAuth2/JWT) süreçlerine takılmamak için 
    FastAPI'nin bağımlılık (dependency) sistemini eziyoruz (override).
    Performans testlerinin amacı güvenlik kapısını değil, motorun hızını ölçmektir.
    """
    db = SessionLocal()
    try:
        # Veritabanında hazırladığımız test vatandaşını bul
        user = db.query(Citizen).filter(Citizen.emailAddress == "hiz@istfix.com").first()
        if user:
            # Tüm raporları (200 adet) çekebilmesi için test anında yetkisini Admin'e yükseltiyoruz
            user.isAdmin = True 
        return user
    finally:
        db.close()

# FastAPI'ye "Gerçek get_current_user yerine benim yazdığım override'ı kullan" diyoruz
app.dependency_overrides[get_current_user] = override_get_current_user


# =====================================================================
# TEST VERİTABANI HAZIRLIĞI (FIXTURES)
# =====================================================================

@pytest.fixture(scope="module")
def setup_performance_db():
    """
    Performans testleri başlamadan önce çalışır ve izole bir veritabanı durumu yaratır.
    NFR-P3 yük testi için sisteme tek seferde (Bulk Insert) 200 adet sahte şikayet basar.
    Scope="module" olduğu için bu dosyadaki tüm testler için sadece bir kez çalışır.
    """
    # [TEARDOWN] Önceki testlerden kalan çöp verileri temizle
    Base.metadata.drop_all(bind=engine)
    # [SETUP] Temiz şemayı oluştur
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    try:
        # 1. Gerekli ana kayıtları (Vatandaş ve Belediye) oluştur
        test_citizen = Citizen(
            name="Hız Testi",
            emailAddress="hiz@istfix.com",
            passwordHash="hashed_placeholder",
            kvkkAccepted=True
        )
        test_municipality = Municipality(
            name="Performans", officialEmail="performans@istfix.com"
        )
        
        db.add(test_citizen)
        db.add(test_municipality)
        db.commit()

        # 2. NFR-P3 Yük Testi Verisi (Data Seeding)
        reports = []
        for i in range(200):
            reports.append(
                Report(
                    CITIZENId=test_citizen.id,
                    MUNICIPALITYId=test_municipality.id,
                    photoUrl="uploads/fake_test_image.jpg",
                    writtenDescription="Bu bir sistem yük (stress) testi raporudur.",
                    latitude=41.0,
                    longitude=29.0,
                    processingStatus="EmailDelivered"
                )
            )
        # Tek tek kaydetmek yerine Bulk Insert ile performansı artırıyoruz
        db.bulk_save_objects(reports)
        db.commit()
        
        # Testlerin çalışması için DB oturumunu teslim et
        yield db
        
    finally:
        # [TEARDOWN] Testler bitince veritabanını tamamen sil ve temiz bırak
        db.close()
        Base.metadata.drop_all(bind=engine)


# =====================================================================
# NON-FUNCTIONAL REQUIREMENTS (NFR) - PERFORMANS TESTLERİ
# =====================================================================

def test_nfr_p3_load_200_reports(setup_performance_db):
    """
    Gereksinim: NFR-P3 (Load/Stress Test)
    Açıklama: Veritabanında 200 rapor varken, harita ekranı için gerekli olan 
              tüm raporları getirme işleminin 5 saniyenin altında tamamlanması gerekir.
    """
    # [ARRANGE - HAZIRLIK]
    headers = {"Authorization": "Bearer fake_test_token"} # Override olduğu için token içeriği önemsiz
    start_time = time.perf_counter() # Yüksek hassasiyetli kronometreyi başlat
    
    # [ACT - AKSİYON]
    response = client.get("/api/reports/me", headers=headers)
    
    end_time = time.perf_counter()
    elapsed_time = end_time - start_time
    
    # [ASSERT - DOĞRULAMA]
    assert response.status_code == 200, f"Beklenmeyen HTTP Durum Kodu: {response.status_code}"
    data = response.json()
    assert len(data) == 200, f"Eksik veri: 200 rapor bekleniyordu, {len(data)} adet geldi."
    
    print(f"\n[NFR-P3] Yük Testi (200 Rapor) Çekilme Süresi: {elapsed_time:.4f} saniye")
    assert elapsed_time < 5.0, f"Sistem başarısız! İşlem limiti (5.0s) aşıldı: {elapsed_time:.4f}s"


def test_nfr_p2_reverse_geocoding_speed():
    """
    Gereksinim: NFR-P2 (Latency Test)
    Açıklama: GPS koordinatlarından ilçe ismini bulma (Reverse Geocoding) algoritması 
              lokal işlem süresi olarak 3 saniyenin altında cevap vermelidir.
    """
    # [ARRANGE & ACT]
    start_time = time.perf_counter()
    # Şile/İstanbul koordinatları ile iç servisi tetikliyoruz
    district = get_municipality_from_coords(41.015137, 28.979530) 
    end_time = time.perf_counter()
    elapsed_time = end_time - start_time
    
    # [ASSERT]
    print(f"\n[NFR-P2] Coğrafi Konum Çözümleme Süresi: {elapsed_time:.4f} saniye (Sonuç: {district})")
    assert elapsed_time < 3.0, f"Geocoding servisi çok yavaş: {elapsed_time:.4f} saniye"


def test_nfr_p1_end_to_end_local_processing_time(setup_performance_db):
    """
    Gereksinim: NFR-P1 (End-to-End Latency)
    Açıklama: Tam akış testi. Bir raporun oluşturulması, resmin yüklenmesi,
              YOLO modelinin resmi işlemesi, Gemini modelinin metin üretmesi, 
              ve e-posta atılması süreçlerinin toplamı 10 saniyenin altında olmalıdır.
    """
    # [ARRANGE - HAZIRLIK]
    headers = {"Authorization": "Bearer fake_test_token"}
    
    # Form datası (Multipart/form-data)
    form_data = {
        "latitude": 41.0,
        "longitude": 29.0,
        "writtenDescription": "NFR-P1 Uçtan uca otomasyon testi."
    }
    
    # YOLO ve görüntü işleme algoritmalarının hata vermemesi için 
    # bellekte (in-memory) geçici, minik bir test fotoğrafı (10x10 piksel) oluşturuyoruz.
    image = Image.new('RGB', (10, 10), color='blue')
    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format='JPEG')
    
    # FastAPI'ye gönderilecek dosya formatı: ("dosya_adi", dosya_bytelari, "mime_type")
    files = {
        "image": ("nfr_test_image.jpg", img_byte_arr.getvalue(), "image/jpeg")
    }
    
    # [ACT - AKSİYON]
    start_time = time.perf_counter()
    
    # Görüntü + Metin içeren tam kapsamlı POST isteğini ateşle
    response = client.post("/api/reports/upload", data=form_data, files=files, headers=headers)
    
    end_time = time.perf_counter()
    elapsed_time = end_time - start_time
    
    # [ASSERT - DOĞRULAMA]
    assert response.status_code == 200, f"Uçtan uca rapor işleme başarısız oldu! Detay: {response.text}"
    
    print(f"\n[NFR-P1] Uçtan Uca Tam İşlem (AI + Mail + DB) Süresi: {elapsed_time:.4f} saniye")
    assert elapsed_time < 10.0, f"Sistem çok yavaş! İşlem limiti (10.0s) aşıldı: {elapsed_time:.4f}s"