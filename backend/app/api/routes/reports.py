# backend/app/api/routes/reports.py
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
import shutil
import os
import uuid

from app.core.database import get_db
from app.models.report import Report
from app.models.citizen import Citizen
from app.schemas.report_schema import ReportResponse
from app.services.ai_service import analyze_image_with_yolo, generate_complaint_text
from app.services.geo_service import get_municipality_from_coords
from app.services.mail_service import send_complaint_email

router = APIRouter()

# Fotoğrafların kaydedileceği klasör yolu
UPLOAD_DIR = "uploads"
# Klasör yoksa oluştur
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload", response_model=ReportResponse)
async def create_report(
    latitude: float = Form(...),
    longitude: float = Form(...),
    writtenDescription: str = Form(None),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
    # current_user: User = Depends(get_current_user)  # <-- Gerçek sistemde DB'den böyle gelir
):
    # --- KULLANICI BİLGİSİ ÇEKME ---
    # Normalde yukarıdaki 'Depends' sayesinde o an login olan kişinin tüm bilgileri 
    # 'current_user' objesine dolar ve 'current_user.email' ile ulaşılır
    
    # Şimdilik test için manuel mail adresi tanımlıyorum:
    # Test için db'deki ilk vatandaşı çekiyoruz (İleride JWT'den gelecek)
    test_citizen = db.query(Citizen).first()
    if not test_citizen:
        raise HTTPException(status_code=400, detail="Sistemde kayıtlı Citizen bulunamadı. Lütfen önce kayıt olun.")
    
    reporter_email = test_citizen.emailAddress # Burası ileride current_user.email olacak

    """
    İstFix Ana Akışı: Fotoğrafı işler, AI analizini yapar, DB'ye kaydeder ve belediyeye SendGrid ile mail atar.
    """

    # 1. Dosya İşlemleri
    file_extension = image.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dosya kaydetme hatası: {str(e)}")

    # 2. AI ve Geo Servisleri Tetikle
    # YOLOv8 ile kategori ve güven skoru tespiti (ISSUE_CLASSIFICATION uyumlu)
    yolo_result = analyze_image_with_yolo(file_path)
    category_label = yolo_result["categoryLabel"] # String'i içinden çekiyoruz
    confidence_score = yolo_result["confidenceScore"] # İleride veritabanına kaydetmek için
    
    # Gemini ile resmi dilekçe metni oluşturma
    complaint_text = generate_complaint_text(category_label)
    
    # Coğrafi Servis ile Belediye Tespiti
    municipality_name = get_municipality_from_coords(latitude, longitude)

    # 3. Veritabanı Kaydı
    final_description = writtenDescription if writtenDescription else complaint_text
    is_ai_generated = False if writtenDescription else True
    
    new_report = Report(
        CITIZENId=test_citizen.id,
        photoUrl=file_path,
        latitude=latitude,
        longitude=longitude,
        writtenDescription=final_description,
        isDescriptionAiGenerated=is_ai_generated,
        processingStatus="Pending"
    )

    try:
        db.add(new_report)
        db.commit()
        db.refresh(new_report)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Veritabanı kayıt hatası: {str(e)}")

    # 4. Mail Gönderimi
    email_subject = f"İstFix Resmi Bildirimi: {category_label.upper()} - {municipality_name}"
    
    # Mail içeriğini  HTML formatına çevir
    html_content = f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: auto; border: 1px solid #eee; padding: 20px;">
        <h2 style="color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px;">İstFix | Altyapı Sorun Bildirimi</h2>
        <p>Sayın Yetkili,</p>
        <p>İstanbul genelinde yürütülen akıllı şehir ve altyapı iyileştirme çalışmaları kapsamında, vatandaşlar tarafından sistemimize bir saha raporu iletilmiştir.</p>

        <div style="background-color: #f9f9f9; border-left: 5px solid #3498db; padding: 15px; margin: 20px 0;">
            <strong>Tespit Edilen Kategori:</strong> {category_label.upper()}<br>
            <strong>Konum:</strong> {municipality_name}<br>
            <strong>Raporu Gönderen:</strong> {reporter_email}<br>  
            <strong>Rapor Özeti:</strong> {final_description}
        </div>

        <p>Ekte, yapay zeka tarafından analiz edilen ve sorunun konumunu/durumunu belgeleyen saha fotoğrafı yer almaktadır.</p>
        <p>Gereğinin yapılmasını ve sürecin takibi için sistemimize geri bildirimde bulunulmasını arz ederiz.</p>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #e0e0e0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
            <div style="max-width: 600px; margin: 0 auto;">
                <p style="font-size: 13px; color: #2c3e50; font-weight: bold; margin-bottom: 5px;">İstFix Akıllı Şehir Raporlama Sistemi</p>
                <p style="font-size: 12px; color: #666; line-height: 1.6; margin-bottom: 15px;">
                    Bu e-posta otomatik bir saha raporudur. Kamu yararı amacıyla tasarlanmıştır.
                </p>
                <p style="font-size: 11px; color: #888; margin-bottom: 10px;">
                    Teknik destek için <a href="mailto:istfix.app@gmail.com" style="color: #3498db; text-decoration: none; border-bottom: 1px solid #3498db;">İstFix Teknik Masası</a> ile iletişime geçebilirsiniz.
                </p>
            </div>
        </footer>
    </div>
    """
    
    # Test için test mailine gönder
    test_receiver_email = "odun.kro@gmail.com" # Test edeceğim mail adresi
    
    print(f"DEBUG: {test_receiver_email} adresine mail gönderimi başlatılıyor...")
    
    mail_sent = send_complaint_email(target_email=test_receiver_email, subject=email_subject, content=html_content, image_path=file_path)

    if mail_sent:
        new_report.processingStatus = "EmailDelivered"
    else:
        new_report.processingStatus = "EmailDispatchFailed"
    
    db.commit()
    return new_report