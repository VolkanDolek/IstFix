# backend/app/services/mail_service.py
import os
import base64
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Attachment, FileContent, FileName, FileType, Disposition
from app.core.config import settings

def send_complaint_email(target_email: str, subject: str, content: str, image_path: str = None) -> bool:
    """
    SendGrid API kullanarak belediyeye veya test kullanıcısına şikayet maili gönderir.
    Fotoğraf varsa Base64 formatına çevirip ek olarak (attachment) maile dahil eder.
    """
    
    if not settings.SENDGRID_API_KEY:
        print("HATA: SendGrid API Key bulunamadı!")
        return False

    # 1. Temel Mail Yapısını Oluştur
    message = Mail(
        from_email=settings.SENDGRID_FROM_EMAIL,
        to_emails=target_email,
        subject=subject,
        html_content=content.replace('\n', '<br>') # Düz metni HTML formatına uygun hale getiriyoruz
    )

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

    # 3. Maili Gönder
    try:
        sg = SendGridAPIClient(settings.SENDGRID_API_KEY)
        response = sg.send(message)
        
        # 202 (Accepted) SendGrid'in başarılı gönderim kodudur
        if response.status_code == 202:
            return True
        else:
            print(f"SendGrid beklenmeyen bir cevap döndü. Status: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"SendGrid API Hatası: {str(e)}")
        return False