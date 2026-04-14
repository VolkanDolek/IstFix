# backend/app/api/routes/reports.py
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
import shutil
import os
import uuid

from app.core.database import get_db
from app.models.report import Report
from app.schemas.report_schema import ReportResponse
from app.services.ai_service import analyze_image_with_yolo, generate_complaint_text
from app.services.geo_service import get_municipality_from_coords

router = APIRouter()

# Fotoğrafların kaydedileceği klasör
UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

@router.post("/upload", response_model=ReportResponse)
async def create_report(
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Flutter'dan gelen fotoğrafı ve konumu işler:
    1. Fotoğrafı sunucuya kaydeder.
    2. YOLOv8 ile hata türünü bulur.
    3. Gemini ile dilekçe yazar.
    4. Geopy ile belediyeyi bulur.
    5. Hepsini veritabanına kaydeder.
    """
    
    # 1. Dosyayı Sunucuya Kaydet (Benzersiz bir isimle)
    file_extension = image.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    # 2. Yapay Zeka İşlemleri
    # YOLO ile analiz (Şimdilik pothole döner)
    category = analyze_image_with_yolo(file_path)
    
    # Gemini ile resmi dilekçe oluşturma
    complaint_text = generate_complaint_text(category)

    # 3. Konum İşlemleri (Belediye Bulma)
    municipality_name = get_municipality_from_coords(latitude, longitude)

    # 4. Veritabanına Kaydet
    # PostGIS formatına uygun konum verisi (POINT(longitude latitude))
    # Not: WKT (Well-Known Text) formatı kullanıyoruz
    point_location = f"POINT({longitude} {latitude})"
    
    new_report = Report(
        user_id=1, # Şimdilik test için 1 nolu kullanıcı
        category=category,
        description=complaint_text,
        image_url=file_path,
        location=point_location,
        municipality=municipality_name,
        status="pending"
    )

    db.add(new_report)
    db.commit()
    db.refresh(new_report)

    return new_report