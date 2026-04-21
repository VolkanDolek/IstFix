from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Tip belirterek (str) bu değişkenlerin kesinlikle var olması gerektiğini söylüyoruz.
    # Eğer .env dosyasında bunlardan biri eksikse, FastAPI sunucusu hiç başlamaz ve uyarır.
    DATABASE_URL: str
    SECRET_KEY: str
    GEMINI_API_KEY: str
    SENDGRID_API_KEY: str
    SENDGRID_FROM_EMAIL: str

    # Pydantic v2 standardı ile .env dosyasını otomatik okuma ayarı
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

# Tüm projenin kullanacağı tek bir ayar nesnesi oluşturuyoruz
settings = Settings()