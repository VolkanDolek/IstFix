import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.database import engine, Base
from app.api.api_router import api_router
from app.core.config import settings

# Modellerin metadata'ya kaydedilmesi için burada import edilmesi şarttır
# Aksi halde create_all komutu tabloları oluşturamaz
from app.models import citizen, report

# 1. Veritabanı tablolarını otomatik oluştur
# Not: Profesyonel projelerde ileride 'Alembic' kullanılmalıdır.
Base.metadata.create_all(bind=engine)

# 2. FastAPI Uygulamasını Başlat
app = FastAPI(
    title="İstFix API", 
    description="İstanbul Akıllı Şehir Altyapı Raporlama Sistemi",
    version="1.0.0"
)

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