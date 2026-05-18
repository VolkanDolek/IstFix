# backend/app/api/routes/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordRequestForm
from app.core.database import get_db
from app.models.citizen import Citizen
from app.models.token import BlacklistedToken
from app.services.token_service import cleanup_expired_tokens
from app.schemas.citizen_schema import CitizenCreate, CitizenResponse
from app.core.security import get_password_hash, verify_password, create_access_token
from app.api.deps import get_current_user, get_current_admin, reusable_oauth2
from datetime import datetime, timedelta, timezone

router = APIRouter()

# Buradaki fazlalık 'oauth2_scheme' silindi. Artık 'reusable_oauth2' kullanıyoruz.

@router.post("/register", response_model=CitizenResponse, status_code=status.HTTP_201_CREATED)
def register(citizen: CitizenCreate, db: Session = Depends(get_db)):
    """Yeni vatandaş (Citizen) kaydeder"""
    # 1. Email daha önce alınmış mı kontrol et
    db_citizen = db.query(Citizen).filter(Citizen.emailAddress == citizen.emailAddress).first()
    if db_citizen:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Bu email adresi zaten kayıtlı."
        )
    
    # 2. Şifreyi şifrele ve veritabanına kaydet
    hashed_pw = get_password_hash(citizen.password)
    
    new_citizen = Citizen(
        name=citizen.name,
        emailAddress=citizen.emailAddress, 
        passwordHash=hashed_pw,
        kvkkAccepted=citizen.kvkkAccepted, # Pydantic zaten True olduğunu doğruladı
        kvkkAcceptedAt=datetime.now(timezone.utc) # GÜNCELLEME: utcnow() YERİNE timezone-aware datetime kullanıyoruz 
    )
    
    try:
        db.add(new_citizen)
        db.commit()
        db.refresh(new_citizen)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Kayıt işlemi sırasında bir veritabanı hatası oluştu."
        )
    
    return new_citizen # Şifreyi silip CitizenResponse şemasına göre döndür

@router.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Kullanıcı girişi yapar ve Token (Dijital Kimlik Kartı) verir.
    5 kez hatalı giriş yapılırsa hesap 15 dakika kilitlenir.
    \n
    **NOT:** 'username' alanına kayıt olunan **Email** adresini yaz ve 'password' alanına şifreyi yaz.
    """
    # 1. Kullanıcıyı bul (OAuth2 form_data.username bekler, biz oraya email gireceğiz)
    citizen = db.query(Citizen).filter(Citizen.emailAddress == form_data.username).first()
    
    # 2. Güvenlik kontrolleri
    if not citizen:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Email veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # A. Hesap şu an kilitli mi kontrol et (GÜNCELLENEN KISIM)
    su_an = datetime.now(timezone.utc)
    
    # Veritabanından gelen tarihe güvenlik amacıyla UTC zaman dilimini (tzinfo) ekliyoruz
    kilit_bitis = citizen.lockoutUntil.replace(tzinfo=timezone.utc) if citizen.lockoutUntil else None

    if kilit_bitis and su_an < kilit_bitis:
        kalan_sure = kilit_bitis - su_an
        dakika = int(kalan_sure.total_seconds() // 60)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Çok fazla hatalı deneme. Hesabınız {dakika + 1} dakika süreyle kilitlenmiştir."
        )

    # B. Şifre doğrulama (Hata sayacı burada çalışır)
    if not verify_password(form_data.password, citizen.passwordHash):
        citizen.failedLoginAttempts += 1
        
        if citizen.failedLoginAttempts >= 5:
            citizen.lockoutUntil = datetime.now(timezone.utc) + timedelta(minutes=15) # GÜNCELLEME: utcnow() YERİNE timezone-aware datetime kullanıyoruz
            citizen.failedLoginAttempts = 0 # Kilidi vurduğumuz için sayacı sıfırlıyoruz
            try:
                db.commit()
            except Exception:
                db.rollback()
                raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Veritabanı hatası oluştu.")
            
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="5 kez hatalı giriş yaptınız. Hesabınız 15 dakika süreyle kilitlendi."
            )
        
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Veritabanı hatası oluştu.")

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Email veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # C. Giriş başarılıysa sayaçları temizle
    citizen.failedLoginAttempts = 0
    citizen.lockoutUntil = None
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Oturum güncellenirken hata oluştu.")
    
    # 3. Her şey doğruysa Token üret ve ver (İçine güvenli UUID'yi koyuyoruz)
    access_token = create_access_token(subject=str(citizen.id))
    
    # Sadece token değil, kullanıcı bilgisini de dönüyoruz
    # Böylece Flutter "isAdmin" bilgisini almak için ikinci bir istek atmak zorunda kalmaz.
    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "user": {
            "name": citizen.name,
            "email": citizen.emailAddress,
            "isAdmin": citizen.isAdmin
        }
    }

# DİKKAT: Buradaki Depends içindeki değer reusable_oauth2 olarak güncellendi
@router.post("/logout")
def logout(token: str = Depends(reusable_oauth2), db: Session = Depends(get_db)):
    """Mevcut Token'ı kara listeye alarak geçersiz kılar."""
    try:
        # Eğer bu token zaten kara listedeyse tekrar eklemeye çalışınca hata almamak için
        exists = db.query(BlacklistedToken).filter(BlacklistedToken.token == token).first()
        if not exists:
            db_token = BlacklistedToken(token=token)
            db.add(db_token)
            db.commit()
    except Exception:
        db.rollback()
        # Hata olsa bile kullanıcıya "çıkış yapıldı" diyebiliriz çünkü token geçersiz hale gelmiş olur. 
        # Bu yüzden hata durumunda da başarılı mesajı döndürüyoruz.
        pass
        
    return {"message": "Başarıyla çıkış yapıldı."}

@router.post("/maintenance/cleanup-tokens", status_code=status.HTTP_200_OK)
def trigger_token_cleanup(
    db: Session = Depends(get_db), 
    current_admin: Citizen = Depends(get_current_admin)
):
    """
    Kara liste temizleme işlemi, yönetici tarafından manuel olarak tetiklenebildiği gibi 
    sistem tarafından 24 saatlik periyot sonunda otomatik olarak da çalıştırılabilmektedir.
    24 saatten eski kara liste kayıtlarını veritabanından siler.
    """
    count = cleanup_expired_tokens(db)
    return {"message": f"Temizlik tamamlandı. {count} adet eski token silindi."}

# Giriş yapmış kullanıcının kendi bilgilerini almasını sağlayan rota
@router.get("/me", response_model=CitizenResponse)
def get_user_me(current_user: Citizen = Depends(get_current_user)):
    """Aktif kullanıcının profil bilgilerini (isAdmin dahil) getirir."""
    return current_user