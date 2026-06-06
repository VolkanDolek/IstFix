# backend/app/api/routes/citizens.py
import random
import uuid
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.citizen import Citizen
from app.models.report import Report
from app.models.municipality import Municipality
from app.schemas.citizen_schema import ForgotPasswordRequest, ResetPasswordConfirm, ChangePasswordRequest, VerifyCodeRequest
from app.api.deps import get_current_user, get_current_admin
from app.core.security import get_password_hash, verify_password
from app.services.mail_service import send_otp_email

router = APIRouter()

# --- 1. AKIŞ: ŞİFREMİ UNUTTUM (KOD GÖNDERME) ---
@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Kullanıcıya 4 haneli sıfırlama kodu gönderir."""
    user = db.query(Citizen).filter(Citizen.emailAddress == data.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı."
        )

    # 4 haneli rastgele kod oluştur
    code = str(random.randint(1000, 9999))
    user.resetCode = code
    # GÜNCELLEME: utcnow() yerine modern timezone-aware datetime kullanıldı. 
    user.resetCodeExpiresAt = datetime.now(timezone.utc) + timedelta(minutes=15)
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Veritabanı hatası: {str(e)}"
        )

    # E-posta içeriği (SendGrid için HTML)
    subject = "IstFix - Şifre Sıfırlama Kodu"
    content = f"""
    <h3>Merhaba {user.name},</h3>
    <p>Şifreni sıfırlamak için doğrulama kodun aşağıdadır:</p>
    <h2 style="color: #C8973A; letter-spacing: 2px;">{code}</h2>
    <p>Bu kod <b>15 dakika</b> süreyle geçerlidir. Eğer bu işlemi sen yapmadıysan, bu maili görmezden gelebilirsin.</p>
    <br>
    <p>İyi günler,<br>IstFix Destek Ekibi</p>
    """
    
    mail_sent = send_otp_email(
        target_email=user.emailAddress, 
        subject=subject, 
        content=content
    )
    
    if not mail_sent:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail="Mail gönderilirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin."
        )
    
    return {"message": "Sıfırlama kodu e-postanıza gönderildi."}

# --- 2. AKIŞ: KOD İLE ŞİFRE SIFIRLAMA ---
@router.post("/reset-password")
def reset_password(data: ResetPasswordConfirm, db: Session = Depends(get_db)):
    """Kod doğruysa şifreyi günceller."""
    user = db.query(Citizen).filter(Citizen.emailAddress == data.email).first()
    
    if not user or user.resetCode != data.code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Geçersiz kod veya e-posta."
        )

    # ESKİ: if datetime.utcnow() > user.resetCodeExpiresAt:
    # GÜNCEL HALİ: veritabanından gelene tzinfo ekleyip kıyaslıyoruz
    expires_at = user.resetCodeExpiresAt.replace(tzinfo=timezone.utc) if user.resetCodeExpiresAt else None
    if expires_at and datetime.now(timezone.utc) > expires_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Kodun süresi dolmuş. Lütfen tekrar kod isteyin."
        )

    # Şifreyi güncelle ve kod alanlarını temizle
    user.passwordHash = get_password_hash(data.newPassword)
    user.resetCode = None
    user.resetCodeExpiresAt = None
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Şifre sıfırlanırken hata oluştu: {str(e)}"
        )
    
    return {"message": "Şifreniz başarıyla sıfırlandı. Yeni şifrenizle giriş yapabilirsiniz."}

# --- 3. AKIŞ: PROFİL İÇİNDEN ŞİFRE DEĞİŞTİRME ---
@router.patch("/change-password")
def change_password(
    pass_data: ChangePasswordRequest, 
    db: Session = Depends(get_db), 
    current_user: Citizen = Depends(get_current_user)
):
    """Giriş yapmış kullanıcının eski şifresini kontrol ederek şifresini değiştirir."""
    # Eski şifreyi doğrula
    if not verify_password(pass_data.oldPassword, current_user.passwordHash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Mevcut şifreniz hatalı."
        )
    
    # Yeni şifreyi hashle ve kaydet
    current_user.passwordHash = get_password_hash(pass_data.newPassword)
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Şifre güncellenirken hata oluştu: {str(e)}"
        )
    
    return {"message": "Şifreniz başarıyla güncellendi."}

# --- ARA AKIŞ: KOD DOĞRULAMA KONTROLÜ ---
@router.post("/verify-reset-code")
def verify_reset_code(data: VerifyCodeRequest, db: Session = Depends(get_db)):
    """Sadece kodun doğru olup olmadığını kontrol eder, şifreyi değiştirmez."""
    user = db.query(Citizen).filter(Citizen.emailAddress == data.email).first()
    
    if not user or user.resetCode != data.code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Girdiğiniz doğrulama kodu hatalı."
        )

    # ESKİ: if datetime.utcnow() > user.resetCodeExpiresAt:
    # GÜNCEL HALİ:
    expires_at = user.resetCodeExpiresAt.replace(tzinfo=timezone.utc) if user.resetCodeExpiresAt else None
    if expires_at and datetime.now(timezone.utc) > expires_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Kodun süresi dolmuş. Lütfen tekrar kod isteyin."
        )

    return {"message": "Kod başarıyla doğrulandı."}

# --- 4. AKIŞ: ADMİN ÖZEL - TÜM KULLANICILARI LİSTELE ---
@router.get("/", status_code=status.HTTP_200_OK)
def get_all_citizens(db: Session = Depends(get_db), current_admin: Citizen = Depends(get_current_admin)):
    """
    Sistem veritabanında kayıtlı olan tüm AKTİF vatandaşların detaylı listesini geriye döner.
    """
    try:
        # GÜNCELLEME: Sadece 'isActive == True' olanları listele (Silinenleri admin de lisede görmesin)
        citizens = db.query(Citizen).filter(Citizen.isActive == True).all()
        return citizens
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Kullanıcı listesi veritabanından çekilirken sistemsel hata oluştu: {str(e)}"
        )
    
# --- 5. AKIŞ: ADMİN ÖZEL - KULLANICI HESABI SİLME (SOFT DELETE) ---
@router.delete("/{citizen_id}", status_code=status.HTTP_200_OK)
def delete_citizen_account_by_admin(citizen_id: str, db: Session = Depends(get_db), current_admin: Citizen = Depends(get_current_admin)):
    """
    Sistem yöneticisinin kullanıcı hesabını 'Soft Delete' mantığıyla pasife almasını (arşivlemesini) sağlar.
    UX Gereği: Backend veriyi korur ama Frontend'e "Kullanıcı silindi" mesajı döner.
    """
    try:
        account_to_delete = db.query(Citizen).filter(Citizen.id == citizen_id).first()
        
        # GÜNCELLEME: Kullanıcı zaten pasifse (silinmişse) hata dön
        if not account_to_delete or not account_to_delete.isActive:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Silinmek istenen kullanıcı hesabı sistemde bulunamadı veya zaten silinmiş."
            )
        
        # GÜNCELLEME: HİYERARŞİK KORUMA VE ROL TABANLI SİLME KISITLAMASI KATMANI
        # Sistem bütünlüğünü ve hiyerarşik güvenliği korumak amacıyla, 'Admin' yetki 
        # sınıfına sahip hesapların silme operasyonları API katmanında bloke edilir.
        if account_to_delete.isAdmin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Yetki İhlali: Sistem yöneticisi (Admin) statüsündeki hesaplar mobil kontrol paneli üzerinden silinemez."
            )
        
        # GÜNCELLEME: SOFT DELETE + KVKK VERİ ANONİMLEŞTİRME (MASKING)
        account_to_delete.isActive = False
        
        # E-postayı boşa çıkarıyoruz ki aynı maille tekrar kayıt olunabilsin
        # Örnek sonuç: deleted_a1b2c3d4_ege@istfix.com
        rastgele_kod = uuid.uuid4().hex[:8]
        account_to_delete.emailAddress = f"deleted_{rastgele_kod}_{account_to_delete.emailAddress}"
        
        # KVKK gereği kişinin adını ve şifre hash'ini de anlamsız hale getiriyoruz
        account_to_delete.name = "Silinmiş Kullanıcı"
        account_to_delete.passwordHash = "deleted_account_no_password"
        
        db.commit()
        
        return {"message": "Kullanıcı hesabı sistemden başarıyla silindi."}
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Hesap imha prosedürü işletilirken kritik bir hata meydana geldi: {str(e)}"
        )