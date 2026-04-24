# backend/app/api/routes/reports.py
import os
import uuid
import shutil
import asyncio # Paralel çalışma için gerekli
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from PIL import Image # Görüntü küçültme için

from app.core.database import get_db
from app.models.report import Report
from app.models.citizen import Citizen
from app.models.municipality import Municipality
from app.schemas.report_schema import ReportResponse, ReportStatusUpdate
from app.schemas.municipality_schema import MunicipalityResponse
from app.services.ai_service import analyze_image_with_yolo, generate_complaint_text
from app.services.geo_service import get_municipality_from_coords
from app.services.mail_service import send_complaint_email
from app.api.deps import get_current_user, get_current_admin

router = APIRouter()

# Fotoğrafların kaydedileceği klasör yolu
UPLOAD_DIR = "uploads"
# Klasör yoksa oluştur
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

def resize_image(input_path: str, output_path: str, size=(1024, 1024)):
    """
    Fotoğrafı en boy oranını koruyarak küçültür ve optimize eder.
    """
    with Image.open(input_path) as img:
        # Fotoğrafın dikey/yatay durumuna göre en boy oranını korur
        img.thumbnail(size, Image.Resampling.LANCZOS)
        # RGB'ye çevir (bazı formatlar sorun çıkarmasın diye)
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        # Kaliteyi %85 yaparak dosya boyutunu ciddi oranda düşür
        img.save(output_path, "JPEG", optimize=True, quality=85)

@router.post("/upload", response_model=ReportResponse)
async def create_report(
    latitude: float = Form(...),
    longitude: float = Form(...),
    writtenDescription: str = Form(None),
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Citizen = Depends(get_current_user)
):
    # --- KULLANICI BİLGİSİ ÇEKME ---
    # Değişiklik : Manuel 'test_citizen' sorgusu kaldırıldı, direkt 'current_user' kullanılıyor.
    reporter_email = current_user.emailAddress

    """
    İstFix Ana Akışı: Fotoğrafı işler, AI analizini yapar, DB'ye kaydeder ve belediyeye SendGrid ile mail atar.
    """

    # 2. Dosya İşlemleri (Orijinal ve Thumbnail)
    file_extension = image.filename.split(".")[-1]
    unique_id = uuid.uuid4()
    original_file_name = f"{unique_id}.{file_extension}"
    original_path = os.path.join(UPLOAD_DIR, original_file_name)
    
    try:
        with open(original_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dosya kaydetme hatası: {str(e)}")

    # --- YENİ: MAİL İÇİN KÜÇÜLTÜLMÜŞ KOPYA OLUŞTUR ---
    resized_file_name = f"{unique_id}_thumb.jpg"
    resized_path = os.path.join(UPLOAD_DIR, resized_file_name)
    
    try:
        # Orijinal dosyayı bozmadan, sadece mail için küçük bir kopyasını yaratıyoruz
        resize_image(original_path, resized_path)
    except Exception as e:
        print(f"DEBUG: Resize hatası (Orijinal kullanılacak): {e}")
        resized_path = original_path # Hata olursa orijinali gönder

    # 3. GEM ve GEO AI Analizlerini Başlat (Paralel)
    # YOLOv8 ile kategori ve güven skoru tespiti (ISSUE_CLASSIFICATION uyumlu)
    yolo_result = analyze_image_with_yolo(original_path) # YOLO tam kalite fotoğrafı görsün
    category_label = yolo_result["categoryLabel"] # String'i içinden çekiyoruz
    confidence_score = yolo_result["confidenceScore"] # İleride veritabanına kaydetmek için

    # --- HIZLANDIRMA NOKTASI: PARALEL ÇALIŞMA ---
    # Gemini metin üretimi ve Geopy konum tespiti dış servislere (internet) bağlıdır.
    # Bunları arka arkaya değil, AYNI ANDA başlatıyoruz.

    print("DEBUG: Gemini ve Geopy aynı anda başlatılıyor...")
    
    # asyncio.gather kullanarak iki süreci paralel koşturuyoruz
    # Not: get_municipality_from_coords senkron ise asyncio.to_thread ile sarmalıyoruz
    tasks = [
        asyncio.to_thread(generate_complaint_text, category_label),
        asyncio.to_thread(get_municipality_from_coords, latitude, longitude)
    ]
    
    # Gemini ile resmi dilekçe metni oluşturma
    # Coğrafi Servis ile Belediye Tespiti
    try:
        # Burada listeyi 'unpack' ederek (*tasks) gather'a veriyoruz
        results = await asyncio.gather(*tasks)
        complaint_text = results[0]  # Gemini'den gelen metin
        municipality_name = results[1]  # Geopy'den gelen belediye ismi
    except Exception as e:
        print(f"DEBUG HATA: Paralel işlemler sırasında bir sorun oluştu: {e}")
        complaint_text = "Rapor özeti oluşturulamadı."
        municipality_name = "Bilinmeyen"

    # --- YENİ: BELEDİYE EŞLEŞTİRME MANTIĞI ---
    # Geo servisinden gelen isimle veritabanındaki belediyeyi buluyoruz
    db_municipality = db.query(Municipality).filter(Municipality.name == municipality_name).first()

    target_municipality_id = None
    target_email = "test1@gmail.com" # Varsayılan fallback mail

    if db_municipality:
        target_municipality_id = db_municipality.id
        target_email = db_municipality.officialEmail
        print(f"DEBUG: Belediye eşleşti: {db_municipality.name}, Mail: {target_email}")
    else:
        print(f"DEBUG: '{municipality_name}' veritabanında bulunamadı. Varsayılan mail kullanılacak.")

    # 4. Veritabanı Kaydı
    final_description = writtenDescription if writtenDescription else complaint_text
    is_ai_generated = False if writtenDescription else True
    
    new_report = Report(
        CITIZENId=current_user.id,
        MUNICIPALITYId=target_municipality_id, # Tespit edilen belediye ID 
        photoUrl=original_path, # DB'de orijinal yol kalsın
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

    # 5. Mail Gönderimi
    email_subject = f"İstFix Resmi Bildirimi: {category_label.upper()} - {municipality_name}"
    
    # Mail içeriğini  HTML formatına çevir
    html_content = f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: auto; border: 1px solid #eee; padding: 20px;">
        <h2 style="color: #0b3d6b; border-bottom: 2px solid #3498db; padding-bottom: 10px;">İstFix | Altyapı Sorun Bildirimi</h2>
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
                <p style="font-size: 13px; color: #0b3d6b; font-weight: bold; margin-bottom: 5px;">İstFix Akıllı Şehir Raporlama Sistemi</p>
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
    
    print(f"DEBUG: {target_email} adresine mail gönderiliyor...")
    mail_sent = send_complaint_email(
        target_email=target_email, # Artık dinamik!
        subject=email_subject, 
        content=html_content, 
        image_path=resized_path
    )

    if mail_sent:
        print(f"DEBUG: EmailDelivered to {target_email}.")
        new_report.processingStatus = "EmailDelivered"
    else:
        new_report.processingStatus = "EmailDispatchFailed"
    
    db.commit()

    # (Opsiyonel) Mail gittikten sonra thumbnail dosyası silebiliriz, çünkü artık ihtiyacımız kalmaz. 
    # Orijinal dosya DB'de kalmaya devam eder.
    if os.path.exists(resized_path):
        os.remove(resized_path)

    return new_report

@router.get("/me", response_model=list[ReportResponse])
def get_reports(
    db: Session = Depends(get_db),
    current_user: Citizen = Depends(get_current_user)
):
    """
    Raporları listeler. 
    Vatandaş ise: Sadece kendi raporlarını görür.
    Admin ise: Veritabanındaki TÜM raporları görür.
    """
    
    # --- YETKİ KONTROLÜ VE FİLTRELEME ---
    if current_user.isAdmin:
        # Admin girişi tüm raporları çeker
        print(f"DEBUG: Admin ({current_user.emailAddress}) tüm raporları çekiyor.")
        reports = db.query(Report).all()
    else:
        # Normal kullanıcı sadece ona ait olanları çeker
        print(f"DEBUG: Kullanıcı ({current_user.emailAddress}) kendi raporlarını çekiyor.")
        reports = db.query(Report).filter(Report.CITIZENId == current_user.id).all()
    
    return reports

@router.patch("/{report_id}/status", response_model=ReportResponse)
def update_report_status(
    report_id: uuid.UUID,
    status_data: ReportStatusUpdate,
    db: Session = Depends(get_db),
    current_admin: Citizen = Depends(get_current_admin)
):
    """
    Sadece yetkili adminlerin rapor durumunu değiştirmesine izin verir.
    """

    # a. Raporu bul ve güncelle
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Rapor bulunamadı.")

    report.processingStatus = status_data.status
    
    try:
        db.commit()
        db.refresh(report)
        return report
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Güncelleme hatası: {str(e)}")