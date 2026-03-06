"""
SRRP v2.0 — Hidroelektrik (HES) Hesaplama Servisi
===================================================
Fiziksel formüle dayalı hidroelektrik güç ve enerji hesabı.

Formül: P = ρ × g × Q × H × η
  ρ = 1000 kg/m³ (suyun yoğunluğu)
  g = 9.81 m/s²  (yerçekimi ivmesi)
  Q = debi (m³/s)
  H = düşü yüksekliği (m)
  η = türbin verimi (0.85 - 0.90)
"""
import math
import requests
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta


# ============================================================
# TÜRBİN VERİMLERİ VE SEÇİM KRİTERLERİ
# ============================================================

TURBINE_SPECS: Dict[str, Dict[str, Any]] = {
    "Kaplan": {
        "efficiency": 0.90,
        "head_range": (2, 40),       # Düşük düşü: 2-40 m
        "flow_range": (0.5, 800),    # Yüksek debi
        "description": "Düşük düşü, yüksek debi — nehir tipi HES",
    },
    "Francis": {
        "efficiency": 0.85,
        "head_range": (10, 700),     # Orta düşü: 10-700 m
        "flow_range": (0.1, 200),    # Orta debi
        "description": "Orta düşü, orta debi — en yaygın baraj türbini",
    },
    "Pelton": {
        "efficiency": 0.88,
        "head_range": (50, 1800),    # Yüksek düşü: 50-1800 m
        "flow_range": (0.01, 50),    # Düşük debi
        "description": "Yüksek düşü, düşük debi — dağlık bölge HES",
    },
}

# Akış katsayıları (arazi tipine göre yağıştan debi tahmini için)
RUNOFF_COEFFICIENTS: Dict[str, float] = {
    "rocky":       0.70,   # Kayalık arazi
    "steep":       0.60,   # Dik yamaç
    "hilly":       0.50,   # Tepelik
    "moderate":    0.40,   # Orta eğim (varsayılan)
    "flat":        0.30,   # Düz arazi
    "forested":    0.25,   # Ormanlık
}


# ============================================================
# ANA HESAPLAMA FONKSİYONLARI
# ============================================================

def calculate_hydro_power(
    flow_rate: float,
    head_height: float,
    turbine_type: str = "Francis",
    efficiency: Optional[float] = None,
) -> Dict[str, Any]:
    """
    Anlık hidroelektrik güç hesabı.
    
    Args:
        flow_rate: Debi (m³/s)
        head_height: Düşü yüksekliği (m)
        turbine_type: Türbin tipi (Kaplan/Francis/Pelton)
        efficiency: Manuel verim (None ise türbin varsayılanı)
    
    Returns:
        {power_kw, power_mw, turbine_type, efficiency, ...}
    """
    rho = 1000.0   # kg/m³
    g = 9.81       # m/s²

    # Türbin verimi
    specs = TURBINE_SPECS.get(turbine_type, TURBINE_SPECS["Francis"])
    eta = efficiency if efficiency is not None else specs["efficiency"]

    # P = ρ × g × Q × H × η (Watt)
    power_watts = rho * g * flow_rate * head_height * eta
    power_kw = power_watts / 1000.0
    power_mw = power_kw / 1000.0

    # Türbin uygunluk kontrolü
    h_min, h_max = specs["head_range"]
    q_min, q_max = specs["flow_range"]
    warnings = []

    if head_height < h_min or head_height > h_max:
        warnings.append(
            f"⚠️ {turbine_type} türbini için önerilen düşü: {h_min}-{h_max} m. "
            f"Girilen: {head_height} m"
        )
    if flow_rate < q_min or flow_rate > q_max:
        warnings.append(
            f"⚠️ {turbine_type} türbini için önerilen debi: {q_min}-{q_max} m³/s. "
            f"Girilen: {flow_rate} m³/s"
        )

    return {
        "power_kw": round(power_kw, 2),
        "power_mw": round(power_mw, 4),
        "turbine_type": turbine_type,
        "turbine_description": specs["description"],
        "efficiency": eta,
        "flow_rate_m3s": flow_rate,
        "head_height_m": head_height,
        "warnings": warnings,
    }


def suggest_turbine_type(head_height: float) -> str:
    """Düşü yüksekliğine göre en uygun türbin tipini öner."""
    if head_height < 20:
        return "Kaplan"
    elif head_height < 200:
        return "Francis"
    else:
        return "Pelton"


# ============================================================
# YAĞIŞTAN DEBİ TAHMİNİ (Open-Meteo Archive API)
# ============================================================

def get_precipitation_data(
    latitude: float,
    longitude: float,
    years: int = 5,
) -> Dict[str, Any]:
    """
    Open-Meteo Archive API'den geçmiş yağış verilerini çeker.
    
    Returns:
        {
            "annual_avg_mm": yıllık ortalama toplam yağış (mm),
            "monthly_avg_mm": {1: 80.2, 2: 65.1, ...},
            "data_years": kaç yıllık veri,
            "error": hata mesajı (varsa)
        }
    """
    end_date = datetime.now() - timedelta(days=5)
    start_date = end_date - timedelta(days=365 * years)

    url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": start_date.strftime("%Y-%m-%d"),
        "end_date": end_date.strftime("%Y-%m-%d"),
        "daily": "precipitation_sum",
        "timezone": "auto",
    }

    try:
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        daily = data.get("daily", {})
        dates = daily.get("time", [])
        precip = daily.get("precipitation_sum", [])

        if not precip:
            return {"error": "Yağış verisi boş"}

        # Aylık ortalamalar (tüm yıllar üzerinden)
        monthly_totals: Dict[int, List[float]] = {m: [] for m in range(1, 13)}
        current_year_month: Dict[str, float] = {}

        for i, dt_str in enumerate(dates):
            if i >= len(precip) or precip[i] is None:
                continue
            year_month = dt_str[:7]  # "2024-03"
            month = int(dt_str[5:7])
            current_year_month.setdefault(year_month, 0.0)
            current_year_month[year_month] += float(precip[i])

        # Her yıl-ay kombinasyonunu aylık totallere grupla
        for ym_key, total in current_year_month.items():
            month = int(ym_key[5:7])
            monthly_totals[month].append(total)

        # Aylık ortalamalar
        monthly_avg: Dict[int, float] = {}
        for month in range(1, 13):
            if monthly_totals[month]:
                monthly_avg[month] = round(
                    sum(monthly_totals[month]) / len(monthly_totals[month]), 1
                )
            else:
                monthly_avg[month] = 0.0

        annual_avg = sum(monthly_avg.values())

        return {
            "annual_avg_mm": round(annual_avg, 1),
            "monthly_avg_mm": monthly_avg,
            "data_years": years,
        }

    except requests.RequestException as e:
        return {"error": f"Open-Meteo API hatası: {e}"}


def estimate_flow_rate(
    monthly_precip_mm: Dict[int, float],
    basin_area_km2: float,
    runoff_coefficient: float = 0.40,
) -> Dict[int, float]:
    """
    Aylık yağış verilerinden aylık ortalama debi tahmini.
    
    Q = (P × A × C) / (T × 1000)
    
    P: aylık toplam yağış (mm = L/m²)
    A: havza alanı (m²)
    C: akış katsayısı (0-1)
    T: ayın saniye sayısı
    
    Sonuç: m³/s (ortalama debi)
    """
    basin_area_m2 = basin_area_km2 * 1_000_000  # km² → m²

    days_in_month = {
        1: 31, 2: 28.25, 3: 31, 4: 30, 5: 31, 6: 30,
        7: 31, 8: 31, 9: 30, 10: 31, 11: 30, 12: 31,
    }

    monthly_flow: Dict[int, float] = {}
    for month, precip_mm in monthly_precip_mm.items():
        seconds_in_month = days_in_month.get(month, 30) * 86400
        # mm → m: /1000
        volume_m3 = (precip_mm / 1000.0) * basin_area_m2 * runoff_coefficient
        flow_m3s = volume_m3 / seconds_in_month
        monthly_flow[month] = round(flow_m3s, 3)

    return monthly_flow


# ============================================================
# YILLIK ÜRETİM HESABI (aylık kırılımlı)
# ============================================================

MONTH_NAMES_TR = [
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
]

DAYS_IN_MONTH = [31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


def calculate_annual_hydro_production(
    latitude: float,
    longitude: float,
    head_height: float,
    turbine_type: str = "Francis",
    flow_rate: Optional[float] = None,
    basin_area_km2: Optional[float] = None,
    runoff_coefficient: float = 0.40,
    efficiency: Optional[float] = None,
) -> Dict[str, Any]:
    """
    Tam kapsamlı yıllık HES üretim hesabı.
    
    Eğer flow_rate verilmişse → sabit debi ile hesap.
    Eğer basin_area_km2 verilmişse → yağıştan aylık debi tahmini yapılır.
    İkisi de verilmişse → flow_rate öncelikli (kullanıcı biliyordur).
    """
    specs = TURBINE_SPECS.get(turbine_type, TURBINE_SPECS["Francis"])
    eta = efficiency if efficiency is not None else specs["efficiency"]
    rho = 1000.0
    g = 9.81

    monthly_production: Dict[str, float] = {}
    monthly_flow_rates: Dict[str, float] = {}
    total_annual_kwh = 0.0
    avg_flow_rate = flow_rate or 0.0

    if flow_rate is not None and flow_rate > 0:
        # SABİT DEBİ MODU: kullanıcı debiyi biliyor
        # Can suyu kesintisi (%15)
        environmental_flow = flow_rate * 0.15
        net_flow_rate = flow_rate - environmental_flow
        
        power_kw = (rho * g * net_flow_rate * head_height * eta) / 1000.0

        for i in range(12):
            hours = DAYS_IN_MONTH[i] * 24
            month_kwh = power_kw * hours
            monthly_production[MONTH_NAMES_TR[i]] = round(month_kwh, 2)
            monthly_flow_rates[MONTH_NAMES_TR[i]] = net_flow_rate
            total_annual_kwh += month_kwh

    elif basin_area_km2 is not None and basin_area_km2 > 0:
        # YAĞIŞ BAZLI DEBİ TAHMİNİ MODU
        precip_data = get_precipitation_data(latitude, longitude)

        if "error" in precip_data:
            # Yağış verisi alınamadıysa fallback
            return {
                "error": precip_data["error"],
                "predicted_annual_production_kwh": 0,
                "monthly_production": {},
            }

        monthly_precip = precip_data["monthly_avg_mm"]
        monthly_flows = estimate_flow_rate(
            monthly_precip, basin_area_km2, runoff_coefficient
        )

        flow_values = []
        for i in range(12):
            month_num = i + 1
            gross_q = monthly_flows.get(month_num, 0.0)
            
            # Can suyu kesintisi (%15)
            environmental_flow = gross_q * 0.15
            net_q = gross_q - environmental_flow
            
            flow_values.append(net_q)

            power_kw = (rho * g * net_q * head_height * eta) / 1000.0
            hours = DAYS_IN_MONTH[i] * 24
            month_kwh = power_kw * hours

            monthly_production[MONTH_NAMES_TR[i]] = round(month_kwh, 2)
            monthly_flow_rates[MONTH_NAMES_TR[i]] = round(net_q, 3)
            total_annual_kwh += month_kwh

        avg_flow_rate = sum(flow_values) / len(flow_values) if flow_values else 0.0
    else:
        return {
            "error": "Debi (m³/s) veya Havza Alanı (km²) belirtilmeli.",
            "predicted_annual_production_kwh": 0,
            "monthly_production": {},
        }

    # Kapasite faktörü
    # Rated power: nominal debi ile hesaplanan güç
    rated_power_kw = (rho * g * avg_flow_rate * head_height * eta) / 1000.0
    capacity_factor = 0.0
    if rated_power_kw > 0:
        capacity_factor = total_annual_kwh / (rated_power_kw * 8760)
        capacity_factor = min(capacity_factor, 1.0)

    # Önerilen türbin tipi
    suggested = suggest_turbine_type(head_height)

    return {
        "predicted_annual_production_kwh": round(total_annual_kwh, 2),
        "rated_power_kw": round(rated_power_kw, 2),
        "avg_flow_rate_m3s": round(avg_flow_rate, 3),
        "gross_flow_rate_m3s": flow_rate if (flow_rate is not None and flow_rate > 0) else None, # Ek bilgi olarak brüt debi (varsa)
        "environmental_flow_deducted": True,
        "head_height_m": head_height,
        "turbine_type": turbine_type,
        "turbine_efficiency": eta,
        "turbine_description": specs["description"],
        "suggested_turbine": suggested,
        "capacity_factor": round(capacity_factor, 3),
        "monthly_production": monthly_production,
        "monthly_flow_rates": monthly_flow_rates,
    }


# ============================================================
# İKİ NOKTA İLE DÜŞÜ HESAPLAMA (ELEVATION API + MESAFE)
# ============================================================

# Cebri Boru (Penstock) Maliyet Tablosu (USD/metre)
# Çelik boru çapı debiye göre değişir; basitleştirilmiş tablo:
PENSTOCK_COST_PER_METER: Dict[str, float] = {
    "small":  120.0,   # < 1 m³/s debi (küçük HES)
    "medium": 250.0,   # 1 - 10 m³/s debi
    "large":  500.0,   # > 10 m³/s debi (büyük HES)
}


def get_elevation(latitude: float, longitude: float) -> Optional[float]:
    """
    Open-Meteo ücretsiz Elevation API ile rakım bilgisi çeker.
    Sonuç metre (m) cinsinden.
    """
    url = "https://api.open-meteo.com/v1/elevation"
    params = {"latitude": latitude, "longitude": longitude}
    try:
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        elevations = data.get("elevation", [])
        if elevations:
            return float(elevations[0])
        return None
    except requests.RequestException:
        return None


def get_elevations_batch(points: list) -> list:
    """
    Birden fazla nokta için tek API çağrısıyla rakım bilgisi çeker.
    points: [{"lat": ..., "lon": ...}, ...]
    """
    lats = ",".join(str(p["lat"]) for p in points)
    lons = ",".join(str(p["lon"]) for p in points)
    url = "https://api.open-meteo.com/v1/elevation"
    params = {"latitude": lats, "longitude": lons}
    try:
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        return [float(e) for e in data.get("elevation", [])]
    except requests.RequestException:
        return []


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    İki GPS koordinatı arasındaki kuş uçuşu mesafe (metre).
    Haversine formülü kullanılır.
    """
    R = 6371000  # Dünya yarıçapı (metre)
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def estimate_penstock_cost(distance_m: float, flow_rate: float = 1.0) -> Dict[str, Any]:
    """
    Cebri boru (penstock) maliyet tahmini.
    
    Args:
        distance_m: Boru uzunluğu (metre) — iki nokta arasındaki mesafe
        flow_rate: Debi (m³/s) — boru çapı belirleme için
    
    Returns:
        {"penstock_length_m", "cost_per_meter_usd", "total_cost_usd", "pipe_class"}
    """
    # Boru sınıfı belirle
    if flow_rate < 1.0:
        pipe_class = "small"
    elif flow_rate < 10.0:
        pipe_class = "medium"
    else:
        pipe_class = "large"

    cost_per_m = PENSTOCK_COST_PER_METER[pipe_class]
    
    # Arazi düzeltme faktörü: gerçek boru hattı kuş uçuşundan %20-30 daha uzun
    terrain_factor = 1.25
    adjusted_length = distance_m * terrain_factor

    total_cost = adjusted_length * cost_per_m

    return {
        "penstock_length_m": round(adjusted_length, 1),
        "bird_fly_distance_m": round(distance_m, 1),
        "terrain_factor": terrain_factor,
        "cost_per_meter_usd": cost_per_m,
        "total_cost_usd": round(total_cost, 2),
        "pipe_class": pipe_class,
    }


def analyze_two_points(
    intake_lat: float, intake_lon: float,
    turbine_lat: float, turbine_lon: float,
    flow_rate: Optional[float] = None,
) -> Dict[str, Any]:
    """
    İki nokta (Su Alma Yapısı + Türbin) arasında:
    1. Rakım farkını (brüt düşü) hesaplar
    2. Mesafeyi hesaplar
    3. Cebri boru maliyetini tahmin eder
    4. Uygun türbin tipini önerir
    
    Returns:
        {
            intake_elevation_m, turbine_elevation_m,
            gross_head_m, distance_m,
            penstock: {...},
            suggested_turbine, warnings
        }
    """
    warnings = []

    # Rakımları batch olarak çek (tek API çağrısı)
    elevations = get_elevations_batch([
        {"lat": intake_lat, "lon": intake_lon},
        {"lat": turbine_lat, "lon": turbine_lon},
    ])

    if len(elevations) < 2:
        return {"error": "Rakım verisi alınamadı. Lütfen koordinatları kontrol edin."}

    intake_elev = elevations[0]
    turbine_elev = elevations[1]
    gross_head = intake_elev - turbine_elev

    if gross_head <= 0:
        warnings.append(
            f"⚠️ Su alma noktası ({intake_elev:.0f} m) türbin noktasından ({turbine_elev:.0f} m) "
            f"yüksek değil! Düşü negatif: {gross_head:.1f} m. Noktaları ters seçmiş olabilirsiniz."
        )
        # Negatif düşüyü yine de göster ama kesin değer al
        abs_head = abs(gross_head) if gross_head != 0 else 1.0
    else:
        abs_head = gross_head

    # Mesafe hesapla
    distance = haversine_distance(intake_lat, intake_lon, turbine_lat, turbine_lon)

    # Cebri boru maliyet tahmini
    penstock = estimate_penstock_cost(distance, flow_rate or 1.0)

    # Uygun türbin
    suggested = suggest_turbine_type(abs_head)

    return {
        "intake_elevation_m": round(intake_elev, 1),
        "turbine_elevation_m": round(turbine_elev, 1),
        "gross_head_m": round(gross_head, 1),
        "distance_m": round(distance, 1),
        "penstock": penstock,
        "suggested_turbine": suggested,
        "warnings": warnings,
    }

