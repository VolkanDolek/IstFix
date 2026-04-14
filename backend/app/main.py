import os
from fastapi import FastAPI
from app.core.database import engine, Base  
from app.models import user, report         # Modelleri tanıması için
from app.api.routes import auth, reports
from fastapi.staticfiles import StaticFiles

# Veritabanı tablolarını oluştur komutu
Base.metadata.create_all(bind=engine)       

# Initialize our API
app = FastAPI(
    title="IstFix API",
    description="Urban Infrastructure Complaint Automation for Istanbul",
    version="1.0.0"
)

# Uploads klasörünü dış dünyaya (URL'ye) aç
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# Auth rotalarını ana uygulamaya tak
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(reports.router, prefix="/api/reports", tags=["Reports"])

# Our first endpoint
@app.get("/")
def root():
    return {"message": "IstFix Server is Running Successfully"}