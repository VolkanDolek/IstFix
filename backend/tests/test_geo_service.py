# tests/test_geo_service.py
import pytest
from unittest.mock import patch, MagicMock
from geopy.exc import GeocoderTimedOut
from app.services.geo_service import get_municipality_from_coords

# Tüm testlerde geolocator.reverse fonksiyonunu taklit etmek için @patch kullanıyoruz
@patch("app.services.geo_service.geolocator.reverse")
def test_get_municipality_success(mock_reverse):
    """
    Sistemin koordinatları başarıyla bir adrese çevirdiği 
    ve içinden ilçe (town) bilgisini doğru ayıkladığı senaryoyu test eder.
    """
    # 1. Hazırlık (Arrange) - Sahte bir lokasyon objesi oluştur
    mock_location = MagicMock()
    mock_location.raw = {
        'address': {
            'town': 'Kadıköy',
            'country': 'Türkiye'
        }
    }
    mock_reverse.return_value = mock_location

    # 2. Aksiyon (Act)
    result = get_municipality_from_coords(40.99, 29.02)

    # 3. Doğrulama (Assert)
    assert result == "Kadıköy"
    # Fonksiyonun tam olarak doğru parametrelerle ve 3 saniye kuralıyla çağrıldığını doğrula
    mock_reverse.assert_called_once_with("40.99, 29.02", timeout=3)

@patch("app.services.geo_service.geolocator.reverse")
def test_get_municipality_unknown_location(mock_reverse):
    """
    Koordinat bulunduğunda ancak adres detaylarında ilçe (town/county) 
    verisi olmadığında sistemin 'Bilinmeyen Konum' dönmesini test eder.
    """
    mock_location = MagicMock()
    # İlçe verisi kasten eksik bırakıldı
    mock_location.raw = {
        'address': {
            'country': 'Türkiye'
        }
    }
    mock_reverse.return_value = mock_location

    result = get_municipality_from_coords(41.0, 28.0)
    assert result == "Bilinmeyen Konum"

@patch("app.services.geo_service.geolocator.reverse")
def test_get_municipality_timeout(mock_reverse):
    """
    SDD DG-P2 Kuralı: Harita servisi 3 saniye içinde cevap vermezse
    sistemin çökmeden 'Zaman Aşımı' durumuna geçmesini test eder.
    """
    # Fonksiyon çağrıldığında kasten GeocoderTimedOut hatası fırlatmasını sağla
    mock_reverse.side_effect = GeocoderTimedOut("Nominatim yanıt vermedi")

    result = get_municipality_from_coords(41.0, 29.0)
    
    assert result == "Zaman Aşımı"
    mock_reverse.assert_called_once()

@patch("app.services.geo_service.geolocator.reverse")
def test_get_municipality_generic_exception(mock_reverse):
    """
    Bilinmeyen rastgele bir sunucu/sistem hatası oluştuğunda
    sistemin 'Koordinat Hatası' dönerek çalışmaya devam etmesini test eder.
    """
    # Beklenmeyen genel bir Exception fırlat
    mock_reverse.side_effect = Exception("Beklenmeyen ağ hatası")

    result = get_municipality_from_coords(41.0, 29.0)
    
    assert result == "Koordinat Hatası"