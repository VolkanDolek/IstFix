# tests/test_token_service.py
import pytest
from unittest.mock import MagicMock # Sahte bir veritabanı objesi yaratacağız
from app.services.token_service import cleanup_expired_tokens

def test_cleanup_expired_tokens_success():
    """
    Token temizleme işleminin veritabanında hata olmadan 
    başarıyla çalıştığı senaryoyu test eder.
    """
    # 1. Hazırlık (Arrange) - Sahte bir veritabanı oturumu (Session) oluştur
    mock_db = MagicMock()
    
    # db.query().filter().delete() zincirinin sonucunda '5' sayısını dönmesini simüle et (5 kayıt silinmiş gibi)
    mock_query = mock_db.query.return_value
    mock_filter = mock_query.filter.return_value
    mock_filter.delete.return_value = 5

    # 2. Aksiyon (Act)
    result = cleanup_expired_tokens(mock_db)

    # 3. Doğrulama (Assert)
    assert result == 5
    mock_db.commit.assert_called_once()  # Başarılı olduğu için db.commit() 1 kez çağrılmış olmalı
    mock_db.rollback.assert_not_called() # Hata olmadığı için rollback hiç çağrılmamış olmalı

def test_cleanup_expired_tokens_exception():
    """
    Veritabanı bağlantısının koptuğu veya sorgu hatasının olduğu 
    bir durumda, sistemin çökmeden 0 dönüp rollback yaptığını test eder.
    """
    # 1. Hazırlık (Arrange)
    mock_db = MagicMock()
    
    # Veritabanı sorgusu yapıldığı an kasten bir hata fırlatmasını sağla
    mock_db.query.side_effect = Exception("Yapay Veritabanı Bağlantı Hatası!")

    # 2. Aksiyon (Act)
    result = cleanup_expired_tokens(mock_db)

    # 3. Doğrulama (Assert)
    assert result == 0
    mock_db.rollback.assert_called_once() # Hata olduğu için db.rollback() çalıştırılmış olmalı
    mock_db.commit.assert_not_called()    # Hata olduğu için commit yapılmamış olmalı