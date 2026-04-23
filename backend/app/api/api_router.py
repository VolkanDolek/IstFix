# backend/app/api/api_router.py
from fastapi import APIRouter
from app.api.routes import auth, reports, municipalities # Mevcut rotalarını buraya ekliyoruz

api_router = APIRouter()

# Rotaları birleştir
# prefix: URL'in nasıl başlayacağı (örn: /auth)
# tags: Swagger (docs) üzerinde görünecek başlıklar

# Authentication rotaları
api_router.include_router(
    auth.router, 
    prefix="/auth", 
    tags=["Authentication"]
)

# Rapor yönetimi rotaları
api_router.include_router(
    reports.router, 
    prefix="/reports", 
    tags=["Reports"]
)

# --- GELECEKTE EKLENECEK ROTALAR (ER Diyagramına Göre) ---
# Vatandaş profili ve hesap yönetimi için:
# api_router.include_router(citizens.router, prefix="/citizens", tags=["Citizens"])

# Belediye yönetimi için:
api_router.include_router(
    municipalities.router, 
    prefix="/municipalities", 
    tags=["Municipalities"]
)