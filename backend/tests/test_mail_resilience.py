# tests/test_mail_resilience.py
import pytest
import uuid
import io
from PIL import Image
from unittest.mock import patch
from fastapi import FastAPI, Depends
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

# Proje içi mimari bağımlılıklar
from app.api.routes.reports import router
from app.core.database import get_db, Base
from app.models.citizen import Citizen
from app.models.report import Report
from app.api.deps import get_current_user

# =====================================================================
# 1. TEST VERİTABANI VE ALTYAPI YAPILANDIRMASI
# =====================================================================
TEST_DATABASE_URL = "postgresql://postgres:PASSWORD@localhost:5432/istfix_test"

engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

def override_get_current_user(db: Session = Depends(get_db)):
    """Güvenlik kapısını aşmak için test kullanıcısı döndürür."""
    return db.query(Citizen).filter(Citizen.emailAddress == "resilience@istfix.com").first()

app = FastAPI()
app.include_router(router, prefix="/api/reports")
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user] = override_get_current_user

client = TestClient(app)

# =====================================================================
# 2. SEED & TEARDOWN MEKANİZMASI
# =====================================================================
@pytest.fixture(scope="module", autouse=True)
def setup_resilience_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    try:
        test_citizen = Citizen(
            id=uuid.uuid4(),
            name="Dayanıklılık Test Kullanıcısı",
            emailAddress="resilience@istfix.com",
            passwordHash="hashed_password",
            kvkkAccepted=True
        )
        db.add(test_citizen)
        db.commit()
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

# =====================================================================
# 3. SENDGRID ÇÖKME VE GERİ ÇEKİLME (RETRY & FALLBACK) TESTİ
# =====================================================================

@patch("app.api.routes.reports.analyze_image_with_yolo")
@patch("app.api.routes.reports.generate_complaint_text")
@patch("app.services.mail_service.SendGridAPIClient.send")
@patch("app.services.mail_service.time.sleep") # Test anında 2sn, 4sn bekleyerek donmaması için sleep fonksiyonunu mock'luyoruz
def test_resilience_sendgrid_email_failure_handling(mock_sleep, mock_sendgrid, mock_gemini, mock_yolo):
    """
    Gereksinim: NFR-R1 (Robustness / Fault Tolerance)
    Açıklama: SendGrid e-posta sunucusu tamamen çöktüğünde ve 3 deneme de başarısız olduğunda,
              kullanıcı akışının kesilmediğini (200 OK) fakat rapor durumunun veritabanında
              'EmailDispatchFailed' olarak işaretlendiğini lokal veritabanında doğrular.
    """
    # AI servislerini başarılı taklit ettiriyoruz (Onlar zaten kendi dosyasında test edildi)
    mock_yolo.return_value = {"categoryLabel": "Çevre Kirliliği (Çöp)", "confidenceScore": 0.95}
    mock_gemini.return_value = "Çöp konteyneri taşmış durumda, temizlenmesini arz ederim."
    
    # SendGrid API'ın sürekli ağ hatası (Timeout) verdiğini simüle ediyoruz
    mock_sendgrid.side_effect = Exception("SendGrid SMTP Gateway Timeout (HTTP 504)")
    
    # Bellekte test fotoğrafı oluşturma
    image = Image.new('RGB', (10, 10), color='yellow')
    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format='JPEG')
    
    form_data = {"latitude": 41.012, "longitude": 28.974, "writtenDescription": ""}
    files = {"image": ("mail_fail_test.jpg", img_byte_arr.getvalue(), "image/jpeg")}

    # [ACT] İstek gönderilir
    response = client.post("/api/reports/upload", data=form_data, files=files)

    # [ASSERT]
    # 1. Dış sunucu patlasa bile API son kullanıcıya 200 dönmeli, sistem çökmemeli
    assert response.status_code == 200
    
    # 2. Mail servisinin (mail_service.py:73) NFR-R1 kuralına uyup tam 3 kez şansını denediğini doğrula
    assert mock_sendgrid.call_count == 3
    
    # 3. Veritabanında rapor durumunun 'EmailDispatchFailed' yapıldığını lokal PostgreSQL üzerinde doğrula
    db = TestingSessionLocal()
    failed_report = db.query(Report).filter(Report.categoryLabel == "Çevre Kirliliği (Çöp)").first()
    
    print(f"\n[RESILIENCE TEST] SendGrid çöktüğünde veritabanına yazılan durum: '{failed_report.processingStatus}'")
    assert failed_report.processingStatus == "EmailDispatchFailed"
    db.close()