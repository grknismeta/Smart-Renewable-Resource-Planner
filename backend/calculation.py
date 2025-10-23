import math
from typing import Literal, TypedDict, Any

# --- Şema Tanımları (Lokal) ---

class PinBase(TypedDict):
    """Girdi verisi için basit bir tip tanımı (Flutter'dan gelen JSON'a karşılık gelir)"""
    latitude: float
    longitude: float
    name: str
    type: Literal["Rüzgar Türbini", "Güneş Paneli", "Diğer"] # Mümkün tipleri sınırla
    capacity_mw: float

class PinResult(TypedDict):
    """Çıktı verisi için basit bir tip tanımı (Flutter'a gönderilecek JSON'a karşılık gelir)"""
    latitude: float
    longitude: float
    name: str
    type: str
    capacity_mw: float
    potential_kwh_annual: float
    estimated_cost: float
    roi_years: float
    # Hata durumunda bu alanlar da eklenebilir
    error_message: str

# --- Sabitler ---
CAPACITY_FACTOR_WIND = 0.35
CAPACITY_FACTOR_SOLAR = 0.18

BASE_COST_PER_KW_WIND = 1500.0
BASE_COST_PER_KW_SOLAR = 1000.0

ELECTRICITY_PRICE_USD_PER_KWH = 0.15 
ANNUAL_HOURS = 8760
BASE_WIND_SPEED_MS = 7.0 


def calculate_energy(pin_data: PinBase) -> tuple[float, float, float]:
    """
    Kaynağın tipine göre yıllık enerji, maliyet ve ROI hesaplaması yapar.

    Bu fonksiyonun içindeki tüm veri erişimleri, dışarıdan gelen veriye bağlı olduğu için 
    ana fonksiyonda hata yönetimi önemlidir.
    """
    
    # Veriye güvenli erişim için .get() metodu da kullanılabilir, 
    # ancak TypedDict kullanıldığı için mevcut erişim korunmuştur.
    latitude_factor = 1.0 - abs(pin_data["latitude"] - 38.8) / 3.0 
    
    potential_kwh_annual = 0.0
    estimated_cost = 0.0
    
    resource_type = pin_data["type"].lower()
    capacity_mw = pin_data["capacity_mw"]
    
    if resource_type == "rüzgar türbini":
        potential_kwh_annual = (
            capacity_mw * 1000 * ANNUAL_HOURS * CAPACITY_FACTOR_WIND * latitude_factor
        )
        estimated_cost = capacity_mw * 1000 * BASE_COST_PER_KW_WIND
        
    elif resource_type == "güneş paneli":
        potential_kwh_annual = (
            capacity_mw * 1000 * ANNUAL_HOURS * CAPACITY_FACTOR_SOLAR * latitude_factor
        )
        estimated_cost = capacity_mw * 1000 * BASE_COST_PER_KW_SOLAR
        
    else:
        potential_kwh_annual = capacity_mw * 1000 * ANNUAL_HOURS * 0.4 * latitude_factor
        estimated_cost = capacity_mw * 1000 * 1200 

    # --- ROI (Yatırımın Geri Dönüşü) Hesaplaması ---
    annual_revenue_usd = potential_kwh_annual * ELECTRICITY_PRICE_USD_PER_KWH
    
    # Sıfıra bölme hatasına karşı koruma (ZeroDivisionError)
    roi_years = estimated_cost / annual_revenue_usd if annual_revenue_usd > 0 else 999.0
    
    return potential_kwh_annual, estimated_cost, roi_years

def simulate_energy_calculation_safe(pin_data: dict[str, Any]) -> dict[str, Any]:
    """
    Güvenli Ana simülasyon fonksiyonu: Hata yakalama (try/except) ile Flutter'a 
    her zaman bir cevap dönmeyi garanti eder.
    
    Not: Girdi tipi PinBase yerine daha genel olan dict[str, Any] yapılmıştır.
    """
    
    try:
        # Girdi verisinin PinBase şemasına uygun olduğunu varsayarak hesaplama yap.
        potential_kwh_annual, estimated_cost, roi_years = calculate_energy(pin_data)
        
        # Başarılı sonuç
        return {
            "latitude": pin_data.get("latitude", 0.0),
            "longitude": pin_data.get("longitude", 0.0),
            "name": pin_data.get("name", "Bilinmiyor"),
            "type": pin_data.get("type", "Bilinmiyor"),
            "capacity_mw": pin_data.get("capacity_mw", 0.0),
            "potential_kwh_annual": potential_kwh_annual,
            "estimated_cost": estimated_cost,
            "roi_years": roi_years,
            "error_message": "" # Hata yok
        }
        
    except KeyError as e:
        # Flutter'dan gelen JSON'da eksik anahtar (key) varsa bu yakalanır.
        hata_mesaji = f"Girdi verisinde eksik anahtar (KeyError): {e}. Lütfen Flutter'dan gelen JSON'u kontrol edin."
        print("HATA:", hata_mesaji)
        return {
            "error_message": hata_mesaji
        }
    
    except Exception as e:
        # Diğer tüm hataları (mantıksal veya tip hatası) yakalar.
        hata_mesaji = f"Hesaplama sırasında beklenmedik bir hata oluştu: {e}"
        print("HATA:", hata_mesaji)
        return {
            "error_message": hata_mesaji
        }