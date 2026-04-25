# backend/app/services/geo_service.py
from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut

# Geopy'yi başlat (user_agent kısmına projemizin adını yazmalıyız)
geolocator = Nominatim(user_agent="istfix_app")

def get_municipality_from_coords(latitude: float, longitude: float) -> str:
    """
    Enlem ve boylamı alır, İstanbul'daki ilgili ilçeyi döndürür.
    SDD DG-P2 Kuralı: İstek 3 saniye içinde tamamlanmalıdır.
    """
    try:
        # Koordinatları adrese çevir (Reverse Geocoding) - TIMEOUT 3 SANİYE OLARAK GÜNCELLENDİ
        location = geolocator.reverse(f"{latitude}, {longitude}", timeout=3)
        
        if location and 'address' in location.raw:
            address = location.raw['address']
            
            # Geopy ilçe bilgisini 'town', 'city_district' veya 'county' içinde tutar
            district = address.get('town') or address.get('city_district') or address.get('county')
            
            if district:
                # İleride veritabanındaki MUNICIPALITY tablosuyla eşleştirmek için 
                # sadece ilçenin adını (Örn: "Kadıköy") dönüyoruz.
                return district
        
        return "Bilinmeyen Konum"
        
    except GeocoderTimedOut:
        # SDD'ye göre: 3 saniyeyi geçerse Geocoding Failure state'ine geç
        print("UYARI: Harita Servisi (Nominatim) 3 saniye içinde cevap veremedi.")
        return "Zaman Aşımı"
    except Exception as e:
        print(f"Koordinat Hatası: {str(e)}")
        return "Koordinat Hatası"