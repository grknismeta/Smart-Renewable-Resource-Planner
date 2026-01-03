import numpy as np
from scipy.spatial.distance import cdist
from typing import List, Dict, Any, Optional

class InterpolationService:
    """
    Dağınık (scattered) veri noktalarından (şehir verisi, grid verisi)
    tüm Türkiye yüzeyi için düzenli bir ızgara (regular grid) oluşturur.
    Bullseye etkisini azaltmak için IDW (Inverse Distance Weighting) kullanılır.
    """

    @staticmethod
    def interpolate_points(
        points: List[Dict[str, float]], 
        value_key: str,
        resolution: float = 0.1,  # Derece cinsinden (0.1 ~ 11km)
        power: float = 2.0    # IDW Power parameter (düşük = daha 'bulanık', yüksek = daha 'lokal/bubble')
    ) -> List[Dict[str, float]]:
        """
        :param points: List of dicts [{'lat': 39.0, 'lon': 35.0, 'value': 100}, ...]
        :param value_key: The key in dict to interpolate (e.g. 'score', 'wind_speed')
        :param resolution: Grid resolution in degrees
        :param power: IDW weighting power. 1.5-2.0 is usually good for weather data.
        :return: List of interpolated points [{'lat': ..., 'lon': ..., 'value': ...}]
        """
        if not points:
            return []

        # 1. Veriyi hazırla
        known_lats = np.array([p['lat'] for p in points])
        known_lons = np.array([p['lon'] for p in points])
        known_values = np.array([p.get(value_key, 0.0) for p in points])

        if len(known_values) == 0:
            return []

        # 2. Grid sınırlarını belirle (Türkiye)
        min_lat, max_lat = 35.8, 42.2
        min_lon, max_lon = 25.5, 45.0
        
        # 3. Hedef ızgarayı oluştur
        grid_lat = np.arange(min_lat, max_lat, resolution)
        grid_lon = np.arange(min_lon, max_lon, resolution)
        
        # Grid noktalarını 2D array olarak hazırla (N_grid_points, 2)
        grid_lon_mesh, grid_lat_mesh = np.meshgrid(grid_lon, grid_lat)
        target_points = np.column_stack((grid_lon_mesh.ravel(), grid_lat_mesh.ravel())) # (X, Y)
        
        known_points = np.column_stack((known_lons, known_lats)) # (X, Y)

        # 4. IDW Hesaplama (Vectorized)
        try:
            # Tüm mesafeleri hesapla (Distance Matrix)
            # target_points (M, 2), known_points (N, 2) -> dists (M, N)
            dists = cdist(target_points, known_points)

            # Sıfıra bölme hatasını önlemek için çok küçük bir epsilon ekleyebilirdik ama
            # tam üstüne gelen nokta varsa IDW sonsuz olur.
            # IDW formülü: u(x) = sum(w_i * u_i) / sum(w_i), w_i = 1 / d^p
            
            # Tam eşleşme durumlarını yönetmek zor, basitçe dist < epsilon olanları 0 yapıp flagleyebiliriz
            # Ya da dists arrayine küçük bir değer ekleyelim.
            epsilon = 1e-6
            dists = np.maximum(dists, epsilon)
            
            weights = 1.0 / (dists ** power)
            
            # Weighted average: (M, N) @ (N,) -> (M,) sum over axis 1
            # numerator = np.sum(weights * known_values, axis=1) # Broadcasting weights (M,N) * values (N,)
            # Bu broadcasting doğru çalışır.
            
            numerator = np.dot(weights, known_values)
            denominator = np.sum(weights, axis=1)
            
            interpolated_values = numerator / denominator
            
            # Grid şekline geri döndür
            grid_z = interpolated_values.reshape(grid_lon_mesh.shape)

        except Exception as e:
            print(f"Interpolation error: {e}")
            return []

        # 5. Sonuçları listeye çevir
        result = []
        rows, cols = grid_z.shape
        
        for r in range(rows):
            for c in range(cols):
                val = float(grid_z[r, c])
                
                # NaN kontrolü
                if np.isnan(val): 
                    val = 0.0
                
                # Basit dış sınır temizliği (sadece Türkiye kutusu içindeki her şeyi döndürüyoruz şimdilik)
                if val > 0.001:
                   result.append({
                       "lat": float(grid_lat_mesh[r, c]),
                       "lon": float(grid_lon_mesh[r, c]),
                       "value": val
                   })
                   
        return result
