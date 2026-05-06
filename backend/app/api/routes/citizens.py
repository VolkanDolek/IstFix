# backend/app/api/routes/citizens.py
import random
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.citizen import Citizen
from app.schemas.citizen_schema import ForgotPasswordRequest, ResetPasswordConfirm, ChangePasswordRequest, VerifyCodeRequest
from app.api.deps import get_current_user
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
    user.resetCodeExpiresAt = datetime.utcnow() + timedelta(minutes=15)
    
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

    if datetime.utcnow() > user.resetCodeExpiresAt:
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

    if datetime.utcnow() > user.resetCodeExpiresAt:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Kodun süresi dolmuş. Lütfen tekrar kod isteyin."
        )

    return {"message": "Kod başarıyla doğrulandı."}