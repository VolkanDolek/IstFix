# backend/app/api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.config import settings
from app.core.security import ALGORITHM
from app.models.citizen import Citizen
from app.models.token import BlacklistedToken

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
    # ÖNCE: Token kara listede mi?
    is_blacklisted = db.query(BlacklistedToken).filter(BlacklistedToken.token == token).first()
    if is_blacklisted:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Oturumunuz sonlandırılmış. Lütfen tekrar giriş yapın.",
            headers={"WWW-Authenticate": "Bearer"},
        )

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

def get_current_admin(
    current_user: Citizen = Depends(get_current_user)
) -> Citizen:
    """
    Sadece admin yetkisi olan kullanıcıları geçiren bağımlılık.
    """
    if not current_user.isAdmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için yönetici yetkisi gereklidir."
        )
    return current_user