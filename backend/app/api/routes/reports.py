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

#1. Klasör yoksa oluştur
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload", response_model=ReportResponse)
async def create_report(
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
    # current_user: User = Depends(get_current_user)  # <-- Gerçek sistemde DB'den böyle gelir
):
    # --- KULLANICI BİLGİSİ ÇEKME ---
    # Normalde yukarıdaki 'Depends' sayesinde o an login olan kişinin tüm bilgileri 
    # 'current_user' objesine dolar ve 'current_user.email' ile ulaşılır
    
    # Şimdilik test için manuel mail adresi tanımlıyorum:
    reporter_email = "test@example.com" # Burası ileride current_user.email olacak

    """
    İstFix Ana Akışı: Fotoğrafı işler, AI analizini yapar, DB'ye kaydeder ve belediyeye SendGrid ile mail atar.
    """

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
    
    # Mail içeriğini  HTML formatına çevir
    html_content = f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: auto; border: 1px solid #eee; padding: 20px;">
    <h2 style="color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px;">İstFix | Altyapı Sorun Bildirimi</h2>
    <p>Sayın Yetkili,</p>
    <p>İstanbul genelinde yürütülen akıllı şehir ve altyapı iyileştirme çalışmaları kapsamında, vatandaşlar tarafından sistemimize bir saha raporu iletilmiştir.</p>
    <div style="background-color: #f9f9f9; border-left: 5px solid #3498db; padding: 15px; margin: 20px 0;">
        <strong>Tespit Edilen Kategori:</strong> {category.upper()}<br>
        <strong>Konum:</strong> {municipality_name}<br>
        <strong>Raporu Gönderen:</strong> {reporter_email}<br>  
        <strong>Rapor Özeti:</strong> {complaint_text}
    </div>

    <p>Ekte, yapay zeka tarafından analiz edilen ve sorunun konumunu/durumunu belgeleyen saha fotoğrafı yer almaktadır.</p>
    
    <p>Gereğinin yapılmasını ve sürecin takibi için sistemimize geri bildirimde bulunulmasını arz ederiz.</p>
    
    <br>
    <p style="font-size: 12px; color: #7f8c8d;">
        <strong>İstFix Teknik Bilgi Notu:</strong><br>
        Bu rapor, vatandaş duyarlılığı ve yapay zeka tabanlı nesne tespiti (YOLOv8 ve Roboflow) teknolojisi kullanılarak otomatik olarak oluşturulmuştur. 
        Coğrafi konum verileri GPS üzerinden doğrulanmıştır.
    </p>

    <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
    
    <footer style="font-size: 11px; color: #bdc3c7; text-align: center;">
        <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
        <p>İstFix - Akıllı Şehir Raporlama Sistemi | 2026</p>
        <p>Bu rapor, {reporter_email} adresli kullanıcı tarafından mobil uygulama üzerinden oluşturulmuştur.</p>
    </footer>
</div>
    """
    
    # Test için test mailine gönder
    test_receiver_email = "odun.kro@gmail.com" # Test edeceğim mail adresi
    
    print(f"DEBUG: {test_receiver_email} adresine mail gönderimi başlatılıyor...")
    
    mail_sent = send_complaint_email(
        target_email=test_receiver_email,
        subject=email_subject,
        content=html_content,
        image_path=file_path
    )

    if mail_sent:
        print(f"BAŞARI: Mail {test_receiver_email} adresine başarıyla iletildi!")
    else:
        # Burası tetikleniyorsa mail_service.py içinde bir sorun vardır
        print("HATA: SendGrid maili gönderemedi. Lütfen API anahtarını ve Sender mailini kontrol et.")
        
    return new_report