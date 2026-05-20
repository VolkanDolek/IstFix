# tests/test_mail_service.py
import pytest
from unittest.mock import patch, mock_open, MagicMock
from app.services.mail_service import send_complaint_email, send_otp_email
from app.core.config import settings

# =====================================================================
# 1. TEMEL YARDIMCI ARAÇLAR (MOCKS)
# =====================================================================

class MockSendGridResponse:
    """SendGrid API'nin başarılı döndürdüğü yanıtı (202 Accepted) taklit eder."""
    def __init__(self, status_code=202):
        self.status_code = status_code

# =====================================================================
# 2. BİRİM TESTLERİ (UNIT TESTS)
# =====================================================================

@patch("app.services.mail_service.settings")
def test_send_complaint_email_missing_api_key(mock_settings):
    """
    API Key tanımlanmamışsa veya .env dosyasından okunamadıysa
    sistemin çökmeden doğrudan False döndüğünü test eder.
    """
    # API key'i sahte olarak siliyoruz
    mock_settings.SENDGRID_API_KEY = None
    
    result = send_complaint_email("test@istfix.com", "Test", "İçerik")
    assert result is False


@patch("app.services.mail_service.SendGridAPIClient")
def test_send_complaint_email_success_first_try(mock_sendgrid_client):
    """
    Mail gönderiminin ilk denemede başarıyla (HTTP 202) sonuçlandığını test eder.
    """
    # SendGrid'in send() metodunu başarılı dönecek şekilde ayarlıyoruz
    mock_sg_instance = MagicMock()
    mock_sg_instance.send.return_value = MockSendGridResponse(202)
    mock_sendgrid_client.return_value = mock_sg_instance

    result = send_complaint_email("test@istfix.com", "Şikayet Var", "<p>Yol bozuk</p>")
    
    assert result is True
    mock_sg_instance.send.assert_called_once()


@patch("app.services.mail_service.os.path.exists")
@patch("builtins.open", new_callable=mock_open, read_data=b"fake_image_bytes")
@patch("app.services.mail_service.SendGridAPIClient")
def test_send_complaint_email_with_attachment(mock_sendgrid_client, mock_file, mock_exists):
    """
    Maile bir fotoğraf (attachment) eklendiğinde Base64 dönüşümünün ve 
    gönderimin başarıyla yapıldığını test eder. Disk okuma işlemleri mocklanmıştır.
    """
    mock_exists.return_value = True  # Dosya diskte varmış gibi davran
    mock_sg_instance = MagicMock()
    mock_sg_instance.send.return_value = MockSendGridResponse(202)
    mock_sendgrid_client.return_value = mock_sg_instance

    result = send_complaint_email("test@istfix.com", "Çukur", "Burada", "dummy_path/test.jpg")
    
    assert result is True
    # Dosyanın okunmak üzere açıldığını doğrula
    mock_file.assert_called_with("dummy_path/test.jpg", 'rb')


@patch("app.services.mail_service.time.sleep")
@patch("app.services.mail_service.SendGridAPIClient")
def test_send_complaint_email_retry_success(mock_sendgrid_client, mock_sleep):
    """
    Exponential Backoff Testi (Başarılı Kurtarma): 
    İlk 2 denemede API hatası alınırsa, sistemin pes etmeyip 3. denemede
    başarıyla maili gönderdiğini test eder. (time.sleep mocklanarak hızlandırıldı)
    """
    mock_sg_instance = MagicMock()
    # side_effect: 1. Çağrı hata verir, 2. Çağrı hata verir, 3. Çağrı 202 Döner
    mock_sg_instance.send.side_effect = [
        Exception("Bağlantı koptu"), 
        Exception("Timeout"), 
        MockSendGridResponse(202)
    ]
    mock_sendgrid_client.return_value = mock_sg_instance

    result = send_complaint_email("test@istfix.com", "Gecikmeli Mail", "İçerik")
    
    assert result is True
    assert mock_sg_instance.send.call_count == 3
    assert mock_sleep.call_count == 2  # 2 defa beklemeye geçmiş olmalı


@patch("app.services.mail_service.time.sleep")
@patch("app.services.mail_service.SendGridAPIClient")
def test_send_complaint_email_retry_exhausted(mock_sendgrid_client, mock_sleep):
    """
    Exponential Backoff Testi (Tam Başarısızlık): 
    Mail gönderimi 3 defa üst üste başarısız olursa, sistemin sonsuz döngüye girmeden
    False döndüğünü test eder.
    """
    mock_sg_instance = MagicMock()
    mock_sg_instance.send.side_effect = Exception("SendGrid Çöktü")
    mock_sendgrid_client.return_value = mock_sg_instance

    result = send_complaint_email("test@istfix.com", "Gitmiyor", "İçerik")
    
    assert result is False
    assert mock_sg_instance.send.call_count == 3
    assert mock_sleep.call_count == 2


@patch("app.services.mail_service.send_complaint_email")
def test_send_otp_email(mock_base_email):
    """
    Şifre sıfırlama rotasının, ana mail fonksiyonunu resimsiz (image_path=None) 
    bir şekilde doğru argümanlarla çağırıp çağırmadığını test eder.
    """
    mock_base_email.return_value = True
    
    result = send_otp_email("user@istfix.com", "OTP", "Kod: 1234")
    
    assert result is True
    mock_base_email.assert_called_once_with(
        "user@istfix.com", "OTP", "Kod: 1234", image_path=None
    )