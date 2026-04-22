# backend/app/api/routes/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordRequestForm
from app.core.database import get_db
from app.models.citizen import Citizen
from app.schemas.citizen_schema import CitizenCreate, CitizenResponse
from app.core.security import get_password_hash, verify_password, create_access_token

router = APIRouter()

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
        passwordHash=hashed_pw
    )
    
    db.add(new_citizen)
    db.commit()
    db.refresh(new_citizen)
    
    return new_citizen # Şifreyi silip CitizenResponse şemasına göre döndür

@router.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Kullanıcı girişi yapar ve Token (Dijital Kimlik Kartı) verir.
    \n
    **NOT:** 'username' alanına kayıt olunan **Email** adresini yaz ve 'password' alanına şifreyi yazın.
    """
    # 1. Kullanıcıyı bul (OAuth2 form_data.username bekler, biz oraya email gireceğiz)
    citizen = db.query(Citizen).filter(Citizen.emailAddress == form_data.username).first()
    
    # 2. Kullanıcı yoksa veya şifre yanlışsa hata ver
    if not citizen or not verify_password(form_data.password, citizen.passwordHash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Email veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 3. Her şey doğruysa Token üret ve ver (İçine güvenli UUID'yi koyuyoruz)
    access_token = create_access_token(subject=str(citizen.id))
    
    return {"access_token": access_token, "token_type": "bearer"}