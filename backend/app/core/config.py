# backend/app/core/config.py
import os
from dotenv import load_dotenv

# .env dosyasını bul ve yükle
load_dotenv()

class Settings:
    # .env içindeki değerleri buraya çekiyoruz
    DATABASE_URL = os.getenv("DATABASE_URL")
    SECRET_KEY = os.getenv("SECRET_KEY")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
    SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
    SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL")

settings = Settings()