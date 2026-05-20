# backend/app/services/ai_service.py
import os
from google.genai import Client
from ultralytics import YOLO
from app.core.config import settings

# 1. Gemini'yi Başlat
client = Client(api_key=settings.GEMINI_API_KEY)

# 2. YOLOv8 Modelini Yükle 
MODEL_PATH = "ml_models/best.pt"
# Eğer dosya varsa modeli yükle, yoksa None yap (Hata vermemesi için)
yolo_model = YOLO(MODEL_PATH) if os.path.exists(MODEL_PATH) else None

# 3. İŞ KURALLARI (BUSINESS LOGIC) - data.yaml sınıflarını ana kategorilere bağlama
CLASS_MAPPING = {
    # Yol Sorunu
    "pothole": "Yol Sorunu (Çukur)",

    # Su Sorunu
    "puddle": "Su Sorunu (Su Birikintisi)",
    "manhole": "Su Sorunu (Rögar Kapağı)",

    # Çevre Kirliliği
    "garbage": "Çevre Kirliliği (Çöp)",
    "garbage-bin": "Çevre Kirliliği (Çöp Kutusu)",

    # Aydınlatma Sorunu
    "street-light": "Aydınlatma Sorunu (Sokak Lambası)",

    # Diğer Sorunlar
    "bench": "Diğer Sorunlar (Bank)",
    "cat": "Diğer Sorunlar (Kedi)",
    "dog": "Diğer Sorunlar (Köpek)",
    "traffic-light": "Diğer Sorunlar (Trafik Işığı)",
    "traffic-sign": "Diğer Sorunlar (Trafik Tabelası)"
}

def analyze_image_with_yolo(image_path: str) -> dict:
    """
    Fotoğrafı YOLOv8'e sokar. 
    Resimdeki sorunları tespit edip en yüksek güven skoruna sahip olanını
    ER Diyagramı (ISSUE_CLASSIFICATION) standartlarına uygun olarak döndürür.
    """
    # Model yüklenmemişse hata dönmesin, varsayılan bir değer dönsün
    if not yolo_model: 
        print("HATA: ml_models/best.pt bulunamadı!")
        return {"categoryLabel": "Bilinmeyen Sorun", "confidenceScore": 0.0}
    
    # YOLO Modelini Çalıştır (Sadece %50 ve üzeri emin olduklarını al)
    results = yolo_model.predict(source=image_path, imgsz=512, conf=0.25)
    
    # Eğer resimde hiçbir anomali/sorun tespit edilemezse:
    if len(results[0].boxes) == 0:
        return {"categoryLabel": "Sorun Tespit Edilemedi", "confidenceScore": 0.0}

    # Resimde birden fazla sorun varsa, modelin "en emin olduğu" sorunu buluyoruz
    boxes = results[0].boxes
    best_box = max(boxes, key=lambda b: float(b.conf[0])) # conf değeri en yüksek olanı al
    
    # Tespit edilen nesnenin ID'sini, adını ve güven skorunu al
    class_id = int(best_box.cls[0].item())
    confidence = float(best_box.conf[0].item())
    
    # Modelin içindeki İngilizce ismi çek (örn: "pothole")
    detected_class_name = results[0].names[class_id] 
    
    # İngilizce ismi sözlükten geçirip senin istediğin Ana Kategori formatına çevir
    # (Eğer sözlükte yoksa, İngilizce ismini direkt yazar)
    mapped_category = CLASS_MAPPING.get(detected_class_name, detected_class_name)

    return {
        "categoryLabel": mapped_category, 
        "confidenceScore": round(confidence, 2)
    }

def generate_complaint_text(category_label: str) -> str:
    """
    Kullanıcının belirlediği kısıtlamalarla kısa ve resmi şikayet metni oluşturur.
    """
    # Eğer YOLO hiçbir şey bulamadıysa Gemini'yi yormayalım
    if category_label == "Sorun Tespit Edilemedi":
        return "Görselde belirgin bir altyapı sorunu tespit edilememiştir. Lütfen kontrol ediniz."

    prompt = f"""
    Sen İstanbul'da yaşayan duyarlı bir vatandaşsın. 
    Karşılaştığın bir altyapı sorunu için belediyeye resmi bir şikayet metni yazıyorsun.
    
    Tespit edilen '{category_label}' sorunu ile ilgili belediyeye iletilmek üzere en fazla 1-2 cümlelik, çok kısa ve resmi bir Türkçe şikayet metni oluştur. 
    
    KESİN KURALLAR:
    1. Sadece sorunu bildiren ve müdahale talep eden temel cümleleri yaz.
    2. Selamlama, başlık, tarih, saygı sözcükleri, isim veya ekstra hiçbir kelime KESİNLİKLE EKLEME.
    3. Metin içerisinde KESİNLİKLE köşeli parantez, yer tutucu veya boşluk doldurma ifadeleri (Örn: [Sokak Adı], [Mahalle], [Belirtilmeyen Konum] vb.) KULLANMA.
    4. Metin, konumdan bağımsız olarak doğrudan soruna odaklanan, jenerik ve kendi başına tam bir cümle olmalıdır.
    """

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=prompt
        )
        
        if response and response.text:
            return response.text.strip()
        else:
            return f"Tespit edilen {category_label} sorununun ivedilikle giderilmesini talep ediyorum."

    except Exception as e:
        print(f"Gemini API Hatası: {e}")
        return f"{category_label} hakkında gerekli onarım çalışmalarının başlatılmasını rica ederim."