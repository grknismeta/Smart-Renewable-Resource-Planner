import os
import glob
import rasterio
import geopandas as gpd
from shapely.geometry import Point, box
import numpy as np

class GeoService:
    def __init__(self):
        print("\n" + "="*50)
        print("🌍 COĞRAFİ ANALİZ MOTORU BAŞLATILIYOR (SOLAR vs WIND)")
        print("="*50)
        
        # Dosya yollarını belirle (backend/data/...)
        # services/geo_service.py -> (dirname) services -> (dirname) app -> (dirname) backend -> (join) data
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.data_dir = os.path.join(base_dir, "data")
        
        # --- 1. SINIRLAR ---
        self.country_border = self._load_shapefile(["TUR_0", "gadm"], "Ülke Sınırı")
        self.provinces_gdf = self._load_shapefile(["TUR_1"], "İl Sınırları")
        self.districts_gdf = self._load_shapefile(["TUR_2"], "İlçe Sınırları")

        # --- 2. YASAKLI & KRİTİK ALANLAR ---
        self.water_gdf = self._load_shapefile(["water"], "Su Kütleleri")
        self.railways_gdf = self._load_shapefile(["railway"], "Tren Yolları")
        self.roads_gdf = self._load_shapefile(["roads"], "Yollar")
        self.buildings_gdf = self._load_shapefile(["building"], "Binalar") # Solar için dost, Rüzgar için düşman
        
        # --- 3. ARAZİ TİPLERİ ---
        self.landuse_gdf = self._load_shapefile(["landuse"], "Arazi Kullanımı")
        self.natural_gdf = self._load_shapefile(["natural"], "Doğal Yapı")
        
        # --- 4. TOPOGRAFYA (SRTM) ---
        self.dem_files = glob.glob(os.path.join(self.data_dir, "dem", "*.tif"))
        print(f"🏔️  {len(self.dem_files)} adet yükseklik verisi hazır.")
        print("\n✅ SİSTEM HAZIR.\n")

    def _load_shapefile(self, keywords, label):
        """İlgili anahtar kelimeleri içeren shapefile'ı bulup yükler."""
        print(f"⏳ Yükleniyor: {label}...")
        for kw in keywords:
            # backend/data/vector/ şuna bakar
            pattern = os.path.join(self.data_dir, "vector", f"*{kw}*.shp")
            files = glob.glob(pattern)
            if files:
                try:
                    return gpd.read_file(files[0])
                except Exception as e:
                    print(f"⚠️ {label} yüklenemedi: {e}")
                    continue
        print(f"❌ {label} için dosya bulunamadı.")
        return None

    def analyze_location(self, lat, lon):
        """Verilen koordinat için kapsamlı analiz yapar."""
        if gpd is None or Point is None:
            return {
                "suitable": False,
                "recommendation": "Gerekli kütüphaneler (geopandas) eksik.",
                "location": {"province": "N/A", "district": "N/A"},
                "elevation": 0, "slope": 0, "restricted_area": [],
                "solar_details": {"suitable": False, "message": "Kütüphane Hatası", "reasons": ["Geopandas yüklü değil"], "notes": []},
                "wind_details": {"suitable": False, "message": "Kütüphane Hatası", "reasons": ["Geopandas yüklü değil"], "notes": []}
            }

        point = Point(lon, lat)
        
        # Ortak Veriler (Konum, Eğim)
        loc_info = self._get_location_info(point, lat, lon)
        elevation, slope = self._get_terrain_data(lat, lon)
        
        # --- 1. GÜNEŞ ANALİZİ (Solar) ---
        solar_result = self._analyze_solar(point, slope)

        # --- 2. RÜZGAR ANALİZİ (Wind) ---
        wind_result = self._analyze_wind(point, slope)

        # --- 3. HİDROELEKTRİK ANALİZİ (Hydro) ---
        hydro_result = self._analyze_hydro(point, elevation)

        # Ülke/İlçe Sınırı Kontrolü
        if self.districts_gdf is not None:
             if not self.districts_gdf.contains(point).any():
                error_msg = "Arazi sınırları dışında (Deniz/Göl veya Sınır Dışı)."
                return self._create_final_response(False, False, False, [error_msg], [error_msg], [error_msg], [], [], [], loc_info, 0, 0, lat, lon)
        
        elif self.country_border is not None:
             if not self.country_border.contains(point).any():
                error_msg = "Türkiye sınırları dışında."
                return self._create_final_response(False, False, False, [error_msg], [error_msg], [error_msg], [], [], [], loc_info, 0, 0, lat, lon)

        return self._create_final_response(
            solar_result['suitable'], wind_result['suitable'], hydro_result['suitable'],
            solar_result['reasons'], wind_result['reasons'], hydro_result['reasons'],
            solar_result['notes'], wind_result['notes'], hydro_result['notes'],
            loc_info, elevation, slope, lat, lon
        )

    # ---------------------------------------------------------
    # ☀️ GÜNEŞ ENERJİSİ ANALİZ MANTIĞI
    # ---------------------------------------------------------
    def _analyze_solar(self, point, slope):
        reasons = []
        notes = []
        is_suitable = True
        is_rooftop = False

        # 1. Bina Kontrolü (Fırsat)
        if self._check_contains(self.buildings_gdf, point):
            is_rooftop = True
            notes.append("🏠 Çatı Tipi GES: Mevcut bina üzerine kurulum.")
        
        # 2. Yasaklı Alanlar (Su ve Ulaşım)
        if self._check_contains(self.water_gdf, point):
            is_suitable = False; reasons.append("Su kütlesi (Göl/Baraj)")
        if self._check_distance(self.railways_gdf, point, 0.0002): # ~20m
            is_suitable = False; reasons.append("Tren yoluna çok yakın")
        if self._check_distance(self.roads_gdf, point, 0.0001): # ~10m
            is_suitable = False; reasons.append("Yol üzerine kurulamaz")

        # 3. Arazi Tipi (Güneş için Yerleşim serbest!)
        forbidden = ['cemetery', 'military'] 
        self._check_type(self.landuse_gdf, point, forbidden, reasons, "Arazi")
        
        # Doğal Engeller
        self._check_type(self.natural_gdf, point, ['wetland', 'cliff', 'glacier'], reasons, "Doğal")

        # Yerleşim yeri ise not düş (Yasaklama)
        if not is_rooftop:
            self._check_type_positive(self.landuse_gdf, point, ['residential', 'commercial', 'industrial'], notes, "🏙️ Kentsel/Ticari alan kurulumu.")

        # 4. Eğim
        # Çatıdaysa eğim sorun değil, arazideyse %35 üstü sorun
        if not is_rooftop and slope > 35:
            is_suitable = False
            reasons.append(f"Arazi GES için çok dik (Eğim: {slope:.1f}°)")

        return {"suitable": is_suitable, "reasons": reasons, "notes": notes}

    # ---------------------------------------------------------
    # 🌬️ RÜZGAR ENERJİSİ ANALİZ MANTIĞI
    # ---------------------------------------------------------
    def _analyze_wind(self, point, slope):
        reasons = []
        notes = []
        is_suitable = True

        # 1. Binalara Mesafe — Türkiye Yenilenebilir Enerji Yönetmeliği: min 1500m
        bldg_dist_m = self._get_distance_m(self.buildings_gdf, point)
        if bldg_dist_m is not None:
            if bldg_dist_m < 1500:
                is_suitable = False
                reasons.append(
                    f"Yerleşim alanına çok yakın ({bldg_dist_m:.0f}m — "
                    "Türkiye yönetmeliği min. 1500m gerektirir)"
                )
            elif bldg_dist_m < 3000:
                notes.append(
                    f"⚠️ En yakın bina {bldg_dist_m:.0f}m uzakta "
                    "(yasal min. 1500m karşılanıyor, ancak dikkat)"
                )
            else:
                notes.append(f"✅ En yakın yerleşim {bldg_dist_m:.0f}m uzakta")
        elif self._check_distance(self.buildings_gdf, point, 0.0135):  # fallback ~1500m
            is_suitable = False
            reasons.append("Yerleşim alanına çok yakın (min. 1500m güvenlik mesafesi gerekli)")
        
        # Şehir merkezinin içine kurulamaz (Landuse Residential)
        forbidden_land = ['residential', 'commercial', 'industrial', 'cemetery', 'military']
        self._check_type(self.landuse_gdf, point, forbidden_land, reasons, "Şehir/Yerleşim alanı")

        # 2. Yasaklı Alanlar
        if self._check_contains(self.water_gdf, point):
            is_suitable = False; reasons.append("Su kütlesi")
        if self._check_distance(self.railways_gdf, point, 0.001): # ~100m
            is_suitable = False; reasons.append("Tren yoluna yakın")
        if self._check_distance(self.roads_gdf, point, 0.001): # ~100m
            is_suitable = False; reasons.append("Anayola yakın")

        # 3. Doğal Engeller
        self._check_type(self.natural_gdf, point, ['wetland', 'cliff'], reasons, "Doğal")

        # 4. Eğim (Rüzgar için tepeler iyidir ama montaj için aşırı dik olmamalı)
        if slope > 40:
            is_suitable = False
            reasons.append(f"Türbin montajı için arazi çok sarp ({slope:.1f}°)")
        elif slope > 10:
            notes.append("⛰️ Yüksek/Eğimli arazi: Rüzgar potansiyeli yüksek olabilir.")

        return {"suitable": is_suitable, "reasons": reasons, "notes": notes}

    # ---------------------------------------------------------
    # 💧 HİDROELEKTRİK ENERJİ ANALİZ MANTIĞI
    # ---------------------------------------------------------
    def _analyze_hydro(self, point, elevation):
        """
        HES kural seti:
        - Su kütlesine yakın veya üzerine kurulamaz (bent/santral için ayrı alan)
        - Su kütlesine 2 km içinde → ideal (akarsuyun yakınında)
        - Su kütlesine 2-10 km → havza hesabı ile uygun olabilir
        - Suyun hiç yakınında değil → uygun değil (GEO aktifken)
        - Su kütlesi shapefile yoksa → uygun (belirsizlik durumu)
        """
        reasons = []
        notes = []
        is_suitable = True

        if self.water_gdf is None:
            notes.append("💧 Su kaynağı verisi yüklenemedi, kör onay verildi.")
            return {"suitable": True, "reasons": [], "notes": notes}

        try:
            # Su kütlesinin üzerinde mi? (Direkt su = HES için ideal baraj yeri)
            on_water = self._check_contains(self.water_gdf, point)
            # 500m içinde su var mı? (Çok yakın = ideal)
            near_water_500m = self._check_distance(self.water_gdf, point, 0.005)   # ~500m
            # 2 km içinde su var mı?
            near_water_2km = self._check_distance(self.water_gdf, point, 0.018)    # ~2km
            # 10 km içinde su var mı?
            near_water_10km = self._check_distance(self.water_gdf, point, 0.09)   # ~10km

            if on_water:
                notes.append("💧 Su kütlesi üzerine: Baraj/Bent kurulumu için ideal konum.")
                notes.append(f"⛰️  Yükseklik: {elevation:.0f} m")
            elif near_water_500m:
                notes.append("✅ Su kaynağına 500m içinde: Nehir tipi HES için mükemmel.")
            elif near_water_2km:
                notes.append("✅ Su kaynağına 2km içinde: Kanal/boru hattı ile uygulanabilir.")
            elif near_water_10km:
                notes.append("⚠️ Su kaynağına 10km içinde: Havza alanı büyükse uygulanabilir.")
                is_suitable = True  # Havza verisi girilerek hesaplanabilir
            else:
                is_suitable = False
                reasons.append("Su kaynağı bulunamadı (10km yarıçapında): HES için yetersiz")

        except Exception as e:
            notes.append(f"Su kaynak analizi sırasında hata: {e}")
            is_suitable = True  # Hata durumunda izin ver

        return {"suitable": is_suitable, "reasons": reasons, "notes": notes}

    # ---------------------------------------------------------
    # 🛠️ YARDIMCI VE ÇIKTI FONKSİYONLARI
    # ---------------------------------------------------------
    def _create_final_response(self, solar_ok, wind_ok, hydro_ok, s_reasons, w_reasons, h_reasons, s_notes, w_notes, h_notes, loc, elev, slope, lat, lon):
        
        # Yasaklı Alan Kutusu (Her üçü de yasaksa kırmızı çizelim)
        restricted_area = []
        if (not solar_ok and not wind_ok and not hydro_ok) and lat != 0:
            d = 0.001
            restricted_area = [
                {"lat": lat+d, "lng": lon-d}, {"lat": lat+d, "lng": lon+d},
                {"lat": lat-d, "lng": lon+d}, {"lat": lat-d, "lng": lon-d}
            ]

        # Genel Tavsiye Mesajı
        if solar_ok and wind_ok and hydro_ok:
            rec = "✅ Arazi Güneş, Rüzgar ve HES için uygun."
        elif solar_ok and wind_ok:
            rec = "✅ Arazi hem Güneş hem Rüzgar için uygun."
        elif solar_ok:
            rec = "🌞 Sadece Güneş Enerjisi için uygun."
        elif wind_ok:
            rec = "🌬️ Sadece Rüzgar Enerjisi için uygun."
        elif hydro_ok:
            rec = "💧 Sadece HES için uygun."
        else:
            rec = "⛔ Bu bölgeye kurulum yapılamaz."

        return {
            "suitable": solar_ok or wind_ok or hydro_ok,
            "recommendation": rec,
            "location": loc,
            "elevation": elev,
            "slope": slope,
            "restricted_area": restricted_area,
            
            "solar_details": {
                "suitable": solar_ok,
                "message": "✅ Uygun" if solar_ok else "⛔ Uygun Değil",
                "reasons": s_reasons,
                "notes": s_notes
            },
            "wind_details": {
                "suitable": wind_ok,
                "message": "✅ Uygun" if wind_ok else "⛔ Uygun Değil",
                "reasons": w_reasons,
                "notes": w_notes
            },
            "hydro_details": {
                "suitable": hydro_ok,
                "message": "✅ Su Kaynağı Mevcut" if hydro_ok else "⛔ Su Kaynağı Bulunamadı",
                "reasons": h_reasons,
                "notes": h_notes
            }
        }

    def _get_location_info(self, point, lat, lon):
        info = {"province": "", "district": ""}
        if self.provinces_gdf is not None:
            # Spatial index (cx) ile hızlı arama
            try:
                m = self.provinces_gdf.cx[lon:lon, lat:lat]
                pip = m[m.contains(point)]
                if not pip.empty: info["province"] = pip.iloc[0].get('NAME_1', '')
            except: pass
            
        if self.districts_gdf is not None:
            try:
                m = self.districts_gdf.cx[lon:lon, lat:lat]
                pip = m[m.contains(point)]
                if not pip.empty: info["district"] = pip.iloc[0].get('NAME_2', '')
            except: pass
        return info

    def _get_terrain_data(self, lat, lon):
        if not self.dem_files or rasterio is None:
            return 0.0, 0.0
            
        for f in self.dem_files:
            try:
                with rasterio.open(f) as src:
                    # Bounding box kontrolü
                    if src.bounds.left <= lon <= src.bounds.right and src.bounds.bottom <= lat <= src.bounds.top:
                        row, col = src.index(lon, lat)
                        elev = src.read(1)[row, col]
                        # Eğim hesabı için komşu piksellere bakmak gerekir ama şimdilik dummy
                        return float(elev), 5.0 
            except: continue
        return 0.0, 0.0

    def _check_contains(self, gdf, point):
        if gdf is not None:
            try:
                m = gdf.cx[point.x:point.x, point.y:point.y]
                return m.contains(point).any()
            except: return False
        return False

    def _check_distance(self, gdf, point, limit):
        if gdf is not None:
            try:
                # Bounding box ile hızlı filtreleme
                bbox = box(point.x - limit, point.y - limit, point.x + limit, point.y + limit)
                m = gdf[gdf.intersects(bbox)]
                if not m.empty:
                    return m.distance(point).min() < limit
            except: return False
        return False

    def _check_type(self, gdf, point, match_list, target_list, label):
        if gdf is not None:
            try:
                m = gdf.cx[point.x:point.x, point.y:point.y]
                pip = m[m.contains(point)]
                if not pip.empty:
                    t = pip.iloc[0].get('fclass', 'bilinmiyor')
                    if t in match_list:
                        target_list.append(f"{label}: {t}")
            except: pass

    def _get_distance_m(self, gdf, point, search_deg: float = 0.05):
        """En yakın geometriye mesafeyi metre olarak döndürür (None → veri yok)."""
        if gdf is None:
            return None
        try:
            bbox = box(
                point.x - search_deg, point.y - search_deg,
                point.x + search_deg, point.y + search_deg,
            )
            nearby = gdf[gdf.intersects(bbox)]
            if nearby.empty:
                return None
            min_deg = float(nearby.distance(point).min())
            # 1° ≈ 111,000 m (Türkiye enlemi için yaklaşık)
            return min_deg * 111_000.0
        except Exception:
            return None

    def _check_type_positive(self, gdf, point, match_list, target_list, msg):
        if gdf is not None:
            try:
                m = gdf.cx[point.x:point.x, point.y:point.y]
                pip = m[m.contains(point)]
                if not pip.empty:
                    t = pip.iloc[0].get('fclass', 'bilinmiyor')
                    if t in match_list:
                        target_list.append(msg)
            except: pass
