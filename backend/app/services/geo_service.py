# backend/app/services/geo_service.py
from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut

# Geopy'yi başlat (user_agent kısmına kendi projemizin adını yazmalıyız ki sistem bizi engellemesin)
geolocator = Nominatim(user_agent="istfix_app")

def get_municipality_from_coords(latitude: float, longitude: float) -> str:
    """Enlem ve boylamı alır, İstanbul'daki ilgili İlçe Belediyesini döndürür."""
    try:
        # Koordinatları adrese çevir (Reverse Geocoding)
        location = geolocator.reverse(f"{latitude}, {longitude}", timeout=5)
        
        if location and 'address' in location.raw:
            address = location.raw['address']
            
            # Geopy ilçe bilgisini 'town', 'city_district' veya 'county' içinde tutar
            district = address.get('town') or address.get('city_district') or address.get('county')
            
            if district:
                return f"{district} Belediyesi"
        
        return "Bilinmeyen Belediye (Koordinat Çözülemedi)"
        
    except GeocoderTimedOut:
        return "Harita Servisi Zaman Aşımına Uğradı"
    except Exception as e:
        return f"Koordinat Hatası: {str(e)}"