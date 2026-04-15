import os
from fastapi import FastAPI
from app.core.database import engine, Base  
from app.models import user, report         # Modelleri tanıması için
from app.api.routes import auth, reports
from app.api.api_router import api_router
from fastapi.staticfiles import StaticFiles

# Veritabanı tablolarını oluştur komutu (Alembic yoksa bu kalmalı)
Base.metadata.create_all(bind=engine)       

# Initialize our API
app = FastAPI(title="İstFix API", version="1.0.0")

# Uploads klasörünü dış dünyaya (URL'ye) aç
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# TEK SATIRLA TÜM API'YI DAHİL ET
app.include_router(api_router, prefix="/api")

# Our first endpoint
@app.get("/")
def root():
    return {"message": "IstFix Server is Running Successfully"}