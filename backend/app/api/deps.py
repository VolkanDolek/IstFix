# backend/app/api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.config import settings
from app.core.security import ALGORITHM
from app.models.citizen import Citizen

# Swagger UI'da "Authorize" butonunun login rotasına bakmasını sağlar
reusable_oauth2 = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def get_current_user(
    db: Session = Depends(get_db), 
    token: str = Depends(reusable_oauth2)
) -> Citizen:
    """
    Bu fonksiyon her korumalı rotada çalışır. 
    Token'ı doğrular ve kullanıcıyı DB'den çekip döndürür.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik bilgileri doğrulanamadı",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # security.py'de üretilen token'ı burada çözüyoruz
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Token içindeki ID ile veritabanında kullanıcıyı arıyoruz
    user = db.query(Citizen).filter(Citizen.id == user_id).first()
    
    if user is None:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
    
    return user