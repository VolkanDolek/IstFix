# backend/app/api/routes/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordRequestForm

from app.core.database import get_db
from app.models.user import User
from app.schemas.user_schema import UserCreate, UserResponse
from app.core.security import get_password_hash, verify_password, create_access_token

router = APIRouter()

@router.post("/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    """Yeni kullanıcı kaydeder"""
    # 1. Email daha önce alınmış mı kontrol et
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Bu email adresi zaten kayıtlı.")
    
    # 2. Şifreyi şifrele ve veritabanına kaydet
    hashed_pw = get_password_hash(user.password)
    new_user = User(email=user.email, hashed_password=hashed_pw)
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user # Şifreyi silip UserResponse şemasına göre döndür

@router.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Kullanıcı girişi yapar ve Token (Kimlik Kartı) verir"""
    # 1. Kullanıcıyı bul
    user = db.query(User).filter(User.email == form_data.username).first()
    
    # 2. Kullanıcı yoksa veya şifre yanlışsa hata ver
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Email veya şifre hatalı.")
    
    # 3. Her şey doğruysa Token üret ve ver
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}