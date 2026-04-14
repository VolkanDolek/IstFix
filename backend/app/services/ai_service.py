# backend/app/services/ai_service.py
import os
import google.generativeai as genai
from ultralytics import YOLO
from app.core.config import settings

# 1. Gemini'yi Başlat
genai.configure(api_key=settings.GEMINI_API_KEY)

# 2. YOLOv8 Modelini Yükle 
# (İleride 'best.pt' dosyasını ml_models klasörüne koyduğumuzda burası aktif olacak)
MODEL_PATH = "ml_models/best.pt"
# yolo_model = YOLO(MODEL_PATH) if os.path.exists(MODEL_PATH) else None

def analyze_image_with_yolo(image_path: str) -> str:
    """Fotoğrafı YOLOv8'e sokar ve kategoriyi döndürür (Örn: pothole)"""
    # Şimdilik modelimiz olmadığı için buraya örnek bir değer döndürüyoruz.
    # Model eklendiğinde buradaki yorum satırlarını kaldıracağız.
    
    # if not yolo_model: return "unknown"
    # results = yolo_model(image_path)
    # detected_class = results[0].names[results[0].probs.top1] 
    # return detected_class
    
    return "pothole" # Şimdilik test için her fotoğrafa "pothole" desin.

def generate_complaint_text(category: str) -> str:
    """Gemini'ye kategoriyi verip resmi bir dilekçe yazdırır"""
    if not settings.GEMINI_API_KEY:
        return "Otomatik şikayet metni oluşturulamadı (API Key eksik)."

    prompt = f"""
    Sen İstanbul'da yaşayan duyarlı bir vatandaşsın. 
    Karşılaştığın bir altyapı sorunu için belediyeye resmi bir şikayet metni yazıyorsun.
    
    Tespit edilen '{category}' sorunu ile ilgili belediyeye iletilmek üzere en fazla 1-2 cümlelik, çok kısa ve resmi bir Türkçe şikayet metni oluştur. 
    Lütfen sadece sorunu bildiren ve müdahale talep eden bu cümleleri yaz; selamlama, başlık, tarih, isim veya ekstra hiçbir kelime kesinlikle ekleme.
    """
    try:
        model = genai.GenerativeModel('gemini-pro')
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return f"Gemini metin üretemedi: {str(e)}"