# tests/test_security.py
import pytest
from datetime import datetime, timezone
from jose import jwt
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    ALGORITHM
)
from app.core.config import settings

def test_password_hashing():
    plain_password = "IstFix_SuperSecret_Password!123"
    hashed_password = get_password_hash(plain_password)
    
    assert hashed_password != plain_password
    assert len(hashed_password) > 0
    
    hashed_password_second_time = get_password_hash(plain_password)
    assert hashed_password != hashed_password_second_time

def test_verify_password():
    plain_password = "SecurePassword2026!"
    wrong_password = "WrongPassword2026!"
    hashed_password = get_password_hash(plain_password)
    
    assert verify_password(plain_password, hashed_password) is True
    assert verify_password(wrong_password, hashed_password) is False

def test_create_access_token():
    test_subject = "testuser@istfix.com"
    token = create_access_token(subject=test_subject)
    
    assert isinstance(token, str)
    
    decoded_payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
    
    assert "sub" in decoded_payload
    assert decoded_payload["sub"] == test_subject
    
    assert "exp" in decoded_payload
    expiration_timestamp = decoded_payload["exp"]
    
    # GÜNCELLEME: Modern timezone-aware tarih çevirisi ve kıyaslaması
    expiration_date = datetime.fromtimestamp(expiration_timestamp, timezone.utc)
    assert expiration_date > datetime.now(timezone.utc)