import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi_utilities import repeat_every

from app.core.database import engine, Base, SessionLocal
from app.api.api_router import api_router
from app.core.config import settings
from app.services.token_service import cleanup_expired_tokens

# Modellerin metadata'ya kaydedilmesi için burada import edilmesi şarttır
# Aksi halde create_all komutu tabloları oluşturamaz
from app.models import citizen, report, municipality, token

# 1. Veritabanı tablolarını otomatik oluştur
# Not: Profesyonel projelerde ileride 'Alembic' kullanılmalıdır.
Base.metadata.create_all(bind=engine)

# 2. FastAPI Uygulamasını Başlat
app = FastAPI(
    title="İstFix API", 
    description="İstanbul Akıllı Şehir Altyapı Raporlama Sistemi",
    version="1.0.0"
)

# --- OTOMATİK BLACKLIST TEMİZLİK GÖREVİ (24 Saatte Bir) ---
@app.on_event("startup")
@repeat_every(seconds=60 * 60 * 24) # 24 saat
def auto_cleanup_task():
    """Arka planda çalışan ve her gün blacklisted token'ları süpüren görev."""
    db = SessionLocal()
    try:
        count = cleanup_expired_tokens(db)
        if count > 0:
            print(f"SİSTEM: Otomatik temizlik yapıldı, {count} eski token silindi.")
    except Exception as e:
        print(f"SİSTEM: Otomatik temizlik sırasında bir hata oluştu: {e}")
    finally:
        db.close()
# ----------------------------------------------------------

# 3. CORS Ayarları (Flutter/Mobil Erişim için Kritik)
# Mobil uygulamanın sunucuyla sorunsuz konuşmasını sağlar.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Geliştirme aşamasında tüm kökenlere izin veriyoruz
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 4. Uploads Klasörünü Oluştur ve Dışarı Aç
# Fotoğrafların URL üzerinden (örn: http://localhost:8000/uploads/...) görülebilmesini sağlar.
UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# 5. Tüm API Rotalarını Dahil Et
# api_router.py içinde tanımladığımız tüm /auth ve /reports rotaları buraya bağlanır.
app.include_router(api_router, prefix="/api")

@app.get("/", tags=["Root"])
def root():
    return {
        "status": "online",
        "project": "IstFix Backend",
        "message": "İstFix Sunucusu Başarıyla Çalışıyor!"
    }