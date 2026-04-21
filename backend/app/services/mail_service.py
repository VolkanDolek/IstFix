# backend/app/services/mail_service.py
import os
import base64
import time
# import ssl
import certifi
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, ReplyTo, Attachment, FileContent, FileName, FileType, Disposition
from app.core.config import settings

# SSL Sertifika kontrolünü geliştirme ortamı için esnetiyoruz (certifi ile)
# Mail gönderme hatasını bu şekilde geçebiliyoruz (geliştirme ortamında self-signed sertifika sorununu aşmak için)
os.environ['SSL_CERT_FILE'] = certifi.where()

# SSL Sertifika kontrolünü devre dışı bırak (geliştirme ortamında self-signed sertifika sorununu aşmak için)
# ssl._create_default_https_context = ssl._create_unverified_context

def send_complaint_email(target_email: str, subject: str, content: str, image_path: str = None) -> bool:
    """
    SendGrid API kullanarak belediyeye veya test kullanıcısına şikayet maili gönderir.
    Fotoğraf varsa Base64 formatına çevirip ek olarak (attachment) maile dahil eder.
    Kurallara göre hata durumunda 3 defaya kadar tekrar dener (Exponential Backoff)
    """
    
    if not settings.SENDGRID_API_KEY:
        print("HATA: SendGrid API Key bulunamadı!")
        return False

    # 1. Temel Mail Yapısını Oluştur
    # content artık saf HTML olduğu için replace('\n', '<br>') KULLANMIYORUZ!!!
    message = Mail(
        from_email=settings.SENDGRID_FROM_EMAIL, # 'istfix.app@gmail.com' olmalı
        to_emails=target_email,
        subject=subject,
        html_content=content 
    )
    
    # Cevaplar vatandaşa değil, destek ekibine gelsin
    message.reply_to = ReplyTo("istfix.app@gmail.com", "İstFix Destek Ekibi")

    # 2. Fotoğraf Varsa Maile Ekle (Attachment)
    if image_path and os.path.exists(image_path):
        try:
            with open(image_path, 'rb') as f:
                data = f.read()
            
            # SendGrid, ekleri Base64 formatında ister
            encoded_file = base64.b64encode(data).decode()
            
            # Dosya uzantısını bul (örn: png, jpg)
            extension = image_path.split('.')[-1].lower()
            file_type = f"image/{extension}"
            file_name = os.path.basename(image_path)
            
            # Eklentiyi SendGrid formatında hazırla
            attachment = Attachment(
                FileContent(encoded_file),
                FileName(file_name),
                FileType(file_type),
                Disposition('attachment')
            )
            message.attachment = attachment
        except Exception as e:
            print(f"Fotoğraf maile eklenirken hata oluştu: {e}")

    # 3. Maili Gönder (3 Deneme Hakkı - NFR-R1 Kuralı)
    max_retries = 3
    for attempt in range(1, max_retries + 1):
        try:
            sg = SendGridAPIClient(settings.SENDGRID_API_KEY)
            response = sg.send(message)
            
            # 202 (Accepted) SendGrid'in başarılı gönderim kodudur
            if response.status_code == 202:
                return True
            else:
                print(f"SendGrid beklenmeyen bir cevap döndü. Status: {response.status_code}")
                
        except Exception as e:
            print(f"SendGrid API Hatası (Deneme {attempt}/{max_retries}): {str(e)}")
        
        # Eğer başarısız olduysa ve hala hakkımız varsa bekle (2sn, 4sn...)
        if attempt < max_retries:
            sleep_time = 2 ** attempt
            print(f"Mail gönderilemedi. {sleep_time} saniye sonra tekrar deneniyor...")
            time.sleep(sleep_time)

    # 3 deneme de başarısız olduysa False dön (reports.py bunu alıp "EmailDispatchFailed" yapacak)
    return False