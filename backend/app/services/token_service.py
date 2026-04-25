# backend/app/services/token_service.py
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.models.token import BlacklistedToken

def cleanup_expired_tokens(db: Session):
    """
    Kara listede bulunan ve üzerinden 24 saat geçmiş token'ları siler.
    """
    # 24 saat öncesinin zamanını hesapla
    threshold_time = datetime.utcnow() - timedelta(hours=24)
    
    try:
        # threshold_time'dan daha eski olanları bul ve sil
        deleted_count = db.query(BlacklistedToken).filter(
            BlacklistedToken.blacklistedAt < threshold_time
        ).delete()
        
        db.commit()
        return deleted_count
    except Exception as e:
        db.rollback()
        print(f"Token temizliği sırasında hata: {str(e)}")
        return 0