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
from app.services.mail_service import send_complaint_email

router = APIRouter()

# Fotoğrafların kaydedileceği klasör yolu
UPLOAD_DIR = "uploads"

@router.post("/upload", response_model=ReportResponse)
async def create_report(
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    İstFix Ana Akışı: Fotoğrafı işler, AI analizini yapar, DB'ye kaydeder ve belediyeye SendGrid ile mail atar.
    """
    
    # 1. 'uploads' klasörünün varlığını kontrol et, yoksa oluştur
    if not os.path.exists(UPLOAD_DIR):
        os.makedirs(UPLOAD_DIR)

    # 2. Fotoğrafı Sunucuya Kaydet
    file_extension = image.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dosya kaydetme hatası: {str(e)}")

    # 3. Yapay Zeka Servislerini Çalıştır
    # YOLOv8 ile kategori tespiti
    category = analyze_image_with_yolo(file_path)
    
    # Gemini ile resmi dilekçe metni oluşturma
    complaint_text = generate_complaint_text(category)

    # 4. Coğrafi Servis ile Belediye Tespiti
    municipality_name = get_municipality_from_coords(latitude, longitude)

    # 5. Veritabanına Kaydet
    # PostGIS formatı: POINT(boylam enlem)
    point_location = f"POINT({longitude} {latitude})"
    
    # NOT: user_id=1 varsayılmıştır. İleride JWT eklendiğinde login olan kullanıcının ID'si dinamik alınacak.
    new_report = Report(
        user_id=1, 
        category=category,
        description=complaint_text,
        image_url=file_path,
        location=point_location,
        municipality=municipality_name,
        status="pending"
    )

    try:
        db.add(new_report)
        db.commit()
        db.refresh(new_report)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Veritabanı kayıt hatası: {str(e)}")

    # 6. Mail Servisini Tetikle (SendGrid)
    email_subject = f"İstFix Resmi Bildirimi: {category.upper()} - {municipality_name}"
    
    # Mail içeriğini şık bir HTML formatına çeviriyoruz
    html_content = f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <h2 style="color: #2c3e50;">Yeni Altyapı Sorunu Bildirimi</h2>
        <p><strong>Sayın Yetkili,</strong></p>
        <p>İstFix sistemi üzerinden ilçeniz sınırları dahilinde yeni bir altyapı sorunu bildirilmiştir.</p>
        
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
            <tr>
                <td style="padding: 8px; border: 1px solid #ddd; background-color: #f9f9f9;"><strong>Tespit Edilen Kategori:</strong></td>
                <td style="padding: 8px; border: 1px solid #ddd;">{category.upper()}</td>
            </tr>
            <tr>
                <td style="padding: 8px; border: 1px solid #ddd; background-color: #f9f9f9;"><strong>İlgili Belediye:</strong></td>
                <td style="padding: 8px; border: 1px solid #ddd;">{municipality_name}</td>
            </tr>
            <tr>
                <td style="padding: 8px; border: 1px solid #ddd; background-color: #f9f9f9;"><strong>Konum (Enlem, Boylam):</strong></td>
                <td style="padding: 8px; border: 1px solid #ddd;">{latitude}, {longitude}</td>
            </tr>
        </table>
        
        <h3 style="color: #2c3e50;">Vatandaş Tarafından Oluşturulan Dilekçe:</h3>
        <blockquote style="border-left: 4px solid #3498db; padding-left: 15px; margin-left: 0; font-style: italic; background-color: #f0f8ff; padding: 10px;">
            {complaint_text.replace('\n', '<br>')}
        </blockquote>
        
        <p><em>Olay yerine ait fotoğraf bu e-postanın ekinde sunulmuştur.</em></p>
        <hr>
        <p style="font-size: 12px; color: #7f8c8d;">İyi çalışmalar dileriz.<br><strong>İstFix Otomatik Bildirim Sistemi</strong></p>
    </div>
    """
    
    # Test için test mailine gönder
    test_receiver_email = "istfix.app@gmail.com" # Test edeceğim mail adresi
    
    mail_sent = send_complaint_email(
        target_email=test_receiver_email,
        subject=email_subject,
        content=html_content,
        image_path=file_path
    )

    if not mail_sent:
        print("UYARI: Şikayet DB'ye kaydedildi ancak SendGrid ile e-posta gönderilemedi.")

    return new_report