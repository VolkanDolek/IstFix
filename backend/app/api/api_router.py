from fastapi import APIRouter
from app.api.routes import auth, reports # Mevcut rotalarını buraya ekliyoruz

api_router = APIRouter()

# Rotaları birleştir
# prefix: URL'in nasıl başlayacağı (örn: /api/v1/reports)
# tags: Swagger (docs) üzerinde görünecek başlıklar

api_router.include_router(
    auth.router, 
    prefix="/auth", 
    tags=["Authentication"]
)

api_router.include_router(
    reports.router, 
    prefix="/reports", 
    tags=["Reports"]
)

# Gelecekte buraya yeni rotalar eklenecek:
# api_router.include_router(users.router, prefix="/users", tags=["Users"])