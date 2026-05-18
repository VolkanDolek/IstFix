# tests/test_ai_service.py
import pytest
from unittest.mock import patch, MagicMock
from app.services.ai_service import analyze_image_with_yolo, generate_complaint_text

# --- 1. YOLOv8 TEST SENARYOLARI ---

@patch('app.services.ai_service.yolo_model')
def test_yolo_no_detection(mock_yolo):
    """
    YOLOv8 çalıştığında resimde hiçbir anomali/nesne bulamazsa
    sistemin çökmeden 'Sorun Tespit Edilemedi' dönmesini test eder.
    """
    # YOLO'nun döndürdüğü karmaşık result objesini taklit et (boş kutu listesi)
    mock_result = MagicMock()
    mock_result.boxes = []
    mock_yolo.predict.return_value = [mock_result]
    
    result = analyze_image_with_yolo("dummy_path.jpg")
    
    assert result["categoryLabel"] == "Sorun Tespit Edilemedi"
    assert result["confidenceScore"] == 0.0

@patch('app.services.ai_service.yolo_model')
def test_yolo_best_confidence_and_mapping(mock_yolo):
    """
    Resimde birden fazla nesne tespit edildiğinde, sistemin en yüksek güven (confidence) 
    skoruna sahip olanı seçtiğini ve İngilizce ismini Türkçe ana kategoriye başarıyla çevirdiğini test eder.
    """
    # PyTorch Tensor davranışını kusursuz taklit eden mini yardımcı sınıf
    class FakeTensor:
        def __init__(self, value):
            self.value = value
        def item(self):
            return self.value
        def __float__(self):
            return float(self.value)
        def __int__(self):
            return int(self.value)

    # İki farklı nesne bulunmuş gibi simüle edeceğiz:
    # 1. Pothole (Çukur) -> %40 emin (0.4)
    # 2. Garbage (Çöp) -> %85 emin (0.85) -> Sistemin bunu seçmesi lazım!
    
    box1 = MagicMock()
    box1.conf = [FakeTensor(0.40)]
    box1.cls = [FakeTensor(0)] # names sözlüğündeki 0. index

    box2 = MagicMock()
    box2.conf = [FakeTensor(0.85)]
    box2.cls = [FakeTensor(1)] # names sözlüğündeki 1. index

    mock_result = MagicMock()
    mock_result.boxes = [box1, box2]
    mock_result.names = {0: "pothole", 1: "garbage"}
    
    mock_yolo.predict.return_value = [mock_result]
    
    result = analyze_image_with_yolo("dummy_path.jpg")
    
    # "garbage" -> CLASS_MAPPING üzerinden "Çevre Kirliliği (Çöp)" olarak çevrilmeli
    assert result["categoryLabel"] == "Çevre Kirliliği (Çöp)"
    assert result["confidenceScore"] == 0.85
    
@patch('app.services.ai_service.yolo_model', None)
def test_yolo_model_not_found():
    """
    Sunucuda 'best.pt' model dosyası bulunmadığında sistemin çökmesini engelleyen
    güvenlik önleminin (None kontrolü) çalışıp çalışmadığını test eder.
    """
    result = analyze_image_with_yolo("dummy_path.jpg")
    
    assert result["categoryLabel"] == "Bilinmeyen Sorun"
    assert result["confidenceScore"] == 0.0


# --- 2. GEMINI AI TEST SENARYOLARI ---

def test_gemini_early_exit_no_issue():
    """
    YOLO sorun bulamadığında Gemini API'ye boşuna istek atılmasını engelleyen
    tasarruf ve güvenlik kuralını test eder.
    """
    result = generate_complaint_text("Sorun Tespit Edilemedi")
    
    assert "belirgin bir altyapı sorunu tespit edilememiştir" in result

@patch('app.services.ai_service.client.models.generate_content')
def test_gemini_successful_generation(mock_generate):
    """
    Gemini API'nin başarılı bir şekilde Türkçe şikayet metni 
    ürettiği ideal senaryoyu test eder.
    """
    # Gemini API'den gelen başarılı yanıtı taklit et
    mock_response = MagicMock()
    mock_response.text = "Göztepe Mahallesindeki çöp yığınlarının acilen temizlenmesini talep ediyorum."
    mock_generate.return_value = mock_response
    
    result = generate_complaint_text("Çevre Kirliliği (Çöp)")
    
    assert result == "Göztepe Mahallesindeki çöp yığınlarının acilen temizlenmesini talep ediyorum."
    mock_generate.assert_called_once()

@patch('app.services.ai_service.client.models.generate_content')
def test_gemini_api_exception(mock_generate):
    """
    Gemini API çökerse, internet giderse veya API kotası dolarsa
    uygulamanın donmak yerine statik/standart (fallback) metni döndürdüğünü test eder.
    """
    # Kasten API hatası fırlat
    mock_generate.side_effect = Exception("API Kotası Doldu!")
    
    category = "Yol Sorunu (Çukur)"
    result = generate_complaint_text(category)
    
    # Statik fallback metninin (hata durumunda üretilen yedeğin) döndüğünü doğrula
    assert category in result
    assert "gerekli onarım çalışmalarının başlatılmasını rica ederim" in result