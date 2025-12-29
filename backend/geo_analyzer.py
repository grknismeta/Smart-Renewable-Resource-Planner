import os
import glob
import rasterio
import geopandas as gpd
from shapely.geometry import Point, box
import numpy as np

class GeoAnalyzer:
    def __init__(self):
        print("\n" + "="*50)
        print("🌍 COĞRAFİ ANALİZ MOTORU BAŞLATILIYOR (SOLAR vs WIND)")
        print("="*50)
        
        # Dosya yollarını belirle (backend/data/...)
        base_dir = os.path.dirname(os.path.abspath(__file__))
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
        point = Point(lon, lat)
        
        # Ortak Veriler (Konum, Eğim)
        loc_info = self._get_location_info(point, lat, lon)
        elevation, slope = self._get_terrain_data(lat, lon)
        
        # --- 1. GÜNEŞ ANALİZİ (Solar) ---
        # Kural: Binalar, çatılar ve yerleşim yerleri UYGUNDUR.
        solar_result = self._analyze_solar(point, slope)

        # --- 2. RÜZGAR ANALİZİ (Wind) ---
        # Kural: Binalardan ve yerleşimden UZAK olmalıdır.
        wind_result = self._analyze_wind(point, slope)

        # Ülke/İlçe Sınırı Kontrolü (Her ikisi için de geçerli)
        # Sınır verisi yoksa bu kontrolü atla (geliştirme ortamı için)
        
        # Öncelik: İlçe Sınırları (Daha hassas, Denizi dışlar)
        if self.districts_gdf is not None:
             if not self.districts_gdf.contains(point).any():
                error_msg = "Arazi sınırları dışında (Deniz/Göl veya Sınır Dışı)."
                return self._create_final_response(False, False, [error_msg], [error_msg], [], [], loc_info, 0, 0, lat, lon)
        
        # Fallback: Ülke Sınırları
        elif self.country_border is not None:
             if not self.country_border.contains(point).any():
                error_msg = "Türkiye sınırları dışında."
                return self._create_final_response(False, False, [error_msg], [error_msg], [], [], loc_info, 0, 0, lat, lon)

        return self._create_final_response(
            solar_result['suitable'], wind_result['suitable'],
            solar_result['reasons'], wind_result['reasons'],
            solar_result['notes'], wind_result['notes'],
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

        # 1. Mesafe Kontrolleri (Rüzgar daha hassas)
        # Binalara en az 500m (0.005 derece) uzak olmalı (Gürültü/Gölgeleme)
        if self._check_distance(self.buildings_gdf, point, 0.005): 
            is_suitable = False
            reasons.append("Yerleşim yerine/Binalara çok yakın (Güvenlik mesafesi)")
        
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
    # 🛠️ YARDIMCI VE ÇIKTI FONKSİYONLARI
    # ---------------------------------------------------------
    def _create_final_response(self, solar_ok, wind_ok, s_reasons, w_reasons, s_notes, w_notes, loc, elev, slope, lat, lon):
        
        # Yasaklı Alan Kutusu (Sadece ikisi de yasaksa kırmızı çizelim)
        restricted_area = []
        if (not solar_ok and not wind_ok) and lat != 0:
            d = 0.001
            restricted_area = [
                {"lat": lat+d, "lng": lon-d}, {"lat": lat+d, "lng": lon+d},
                {"lat": lat-d, "lng": lon+d}, {"lat": lat-d, "lng": lon-d}
            ]

        # Genel Tavsiye Mesajı
        rec = ""
        if solar_ok and wind_ok: rec = "✅ Arazi hem Güneş hem Rüzgar için uygun."
        elif solar_ok: rec = "🌞 Sadece Güneş Enerjisi için uygun (Şehir/Çatı)."
        elif wind_ok: rec = "🌬️ Sadece Rüzgar Enerjisi için uygun (Kırsal)."
        else: rec = "⛔ Bu bölgeye kurulum yapılamaz."

        return {
            "suitable": solar_ok or wind_ok, # En az biri uygunsa true
            "recommendation": rec,
            "location": loc,
            "elevation": elev,
            "slope": slope,
            "restricted_area": restricted_area, # Haritada çizim için
            
            # Solar Sonuçları
            "solar_details": {
                "suitable": solar_ok,
                "message": "✅ Uygun" if solar_ok else "⛔ Uygun Değil",
                "reasons": s_reasons,
                "notes": s_notes
            },
            
            # Wind Sonuçları
            "wind_details": {
                "suitable": wind_ok,
                "message": "✅ Uygun" if wind_ok else "⛔ Uygun Değil",
                "reasons": w_reasons,
                "notes": w_notes
            }
        }

    def _get_location_info(self, point, lat, lon):
        info = {"province": "Bilinmiyor", "district": "Bilinmiyor"}
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
        if not self.dem_files:
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