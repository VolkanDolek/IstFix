# backend/app/services/ai_service.py
import os
from google.genai import Client
from ultralytics import YOLO
from app.core.config import settings

# 1. Gemini'yi Başlat
client = Client(api_key=settings.GEMINI_API_KEY)

# 2. YOLOv8 Modelini Yükle 
# (İleride 'best.pt' dosyasını ml_models klasörüne koyduğumuzda burası aktif olacak)
MODEL_PATH = "ml_models/best.pt"
# yolo_model = YOLO(MODEL_PATH) if os.path.exists(MODEL_PATH) else None

def analyze_image_with_yolo(image_path: str) -> str:
    """
    Fotoğrafı YOLOv8'e sokar. 
    ER Diyagramı (ISSUE_CLASSIFICATION) standartlarına uygun olarak 
    kategori adını ve güven skorunu (confidence) sözlük olarak döndürür.
    """
    # Şimdilik modelimiz olmadığı için buraya örnek bir değer döndürüyoruz.
    # Model eklendiğinde buradaki yorum satırlarını kaldıracağız.
    
    # if not yolo_model: 
    #     return {"categoryLabel": "unknown", "confidenceScore": 0.0}
    
    # results = yolo_model(image_path)
    # en_iyi_tahmin_index = results[0].probs.top1
    # detected_class = results[0].names[en_iyi_tahmin_index] 
    # confidence = float(results[0].probs.top1conf) # YOLO'nun emin olma oranı
    
    # return {"categoryLabel": detected_class, "confidenceScore": confidence}
    
    # Şimdilik test için ER diyagramına uygun sahte bir veri dönüyoruz:
    return {
        "categoryLabel": "pothole", 
        "confidenceScore": 0.96 # %96 emin
    }

def generate_complaint_text(category_label: str) -> str:
    """
    Kullanıcının belirlediği kısıtlamalarla kısa ve resmi şikayet metni oluşturur.
    """
    prompt = f"""
    Sen İstanbul'da yaşayan duyarlı bir vatandaşsın. 
    Karşılaştığın bir altyapı sorunu için belediyeye resmi bir şikayet metni yazıyorsun.
    
    Tespit edilen '{category_label}' sorunu ile ilgili belediyeye iletilmek üzere en fazla 1-2 cümlelik, çok kısa ve resmi bir Türkçe şikayet metni oluştur. 
    Lütfen sadece sorunu bildiren ve müdahale talep eden bu cümleleri yaz; selamlama, başlık, tarih, isim veya ekstra hiçbir kelime kesinlikle ekleme.
    """

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=prompt
        )
        
        if response and response.text:
            # Metni temizleyip döndür
            return response.text.strip()
        else:
            return f"Tespit edilen {category_label} sorununun ivedilikle giderilmesini talep ediyorum."

    except Exception as e:
        print(f"Gemini API Hatası: {e}")
        return f"{category_label} hakkında gerekli onarım çalışmalarının başlatılmasını rica ederim."