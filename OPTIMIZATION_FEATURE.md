# Optimizasyon Bölgesi Seçimi - Özellik Dokümantasyonu

## Genel Bakış

Frontend'de "Alan Seçimi" ve "Optimizasyon" entegrasyonu tamamlandı. Kullanıcılar harita üzerinde bir bölge seçip, backend'teki optimization algoritmasını çağırarak türbin yerleşim optimizasyonu yapabiliyor.

## İş Akışı

1. **Bölge Seçim Modunu Başlat**
   - Sağ üstteki "🔲 Bölge Seç" butonuna tıkla
   - Bölge seçim modu etkinleşir

2. **İlk Nokta (Sol-Üst Köşe)**
   - Haritada sol-üst köşesi olacak noktaya tıkla
   - Ekranda ilk koordinat gösterilir

3. **İkinci Nokta (Sağ-Alt Köşe)**
   - Haritada sağ-alt köşesi olacak noktaya tıkla
   - Harita üzerinde yarı şeffaf mavi dikdörtgen görünür

4. **Hesaplama Yap**
   - "📊 Hesapla" butonuna tıkla
   - Optimizasyon Dialog'u açılır
   - Türbin Modeli ID'sini gir (örn: 1)
   - "Hesapla" butonuna bas

5. **Sonuçları Gör**
   - Optimum türbin yerleşimleri haritada mavi wind iconlarıyla gösterilir
   - Toplam güç, üretim ve türbin sayısı özet olarak verilir

## Teknik Detaylar

### Backend Entegrasyonu

**Endpoint:** `POST /optimization/wind-placement`

**İstek Parametreleri:**
```python
{
    "top_left_lat": float,      # Sol-üst köşe enlem
    "top_left_lon": float,      # Sol-üst köşe boylam
    "bottom_right_lat": float,  # Sağ-alt köşe enlem
    "bottom_right_lon": float,  # Sağ-alt köşe boylam
    "equipment_id": int,        # Türbin ekipman ID
    "min_distance_m": float     # İsteğe bağlı: Türbin arası min mesafe (m)
}
```

**Yanıt:**
```python
{
    "total_capacity_mw": float,         # Toplam kurulu güç (MW)
    "total_annual_production_kwh": float, # Toplam yıllık üretim (kWh)
    "turbine_count": int,               # Yerleştirilen türbin sayısı
    "points": [
        {
            "latitude": float,
            "longitude": float,
            "wind_speed_ms": float,      # Ortalama rüzgar hızı
            "annual_production_kwh": float, # Bu türbinin yıllık üretimi
            "score": float               # Yerleşim puanı
        }
    ]
}
```

### Frontend Bileşenleri

#### 1. **MapProvider** (`lib/providers/map_provider.dart`)

Yeni state'ler:
- `_isSelectingRegion`: Seçim modu açık mı?
- `_selectionTopLeft`: İlk tıklanılan nokta
- `_selectionBottomRight`: İkinci tıklanılan nokta
- `_optimizationResult`: Optimizasyon sonuçları

Yeni metodlar:
- `startSelectingRegion()`: Seçim modunu başlat
- `recordSelectionPoint(LatLng point)`: Nokta kaydı
- `clearRegionSelection()`: Seçimi temizle
- `calculateOptimization()`: Backend'e istek gönder

#### 2. **MapScreen** (`lib/presentation/screens/map_screen.dart`)

- Tıklama handler'ı güncellendi: Seçim modunda noktalar kaydediliyor
- Polygon layer eklendi: Seçilen dikdörtgen gösterilir
- Optimizasyon marker'ları eklendi: Sonuç türbinleri mavi wind iconlarıyla gösterilir
- Kontrol butonları: "Bölge Seç" ve "Hesapla" butonları

#### 3. **Yeni Widgetler**

**RegionSelectionIndicator** - Bölge seçim süreci hakkında feedback:
- Hangi adımda olunduğunu gösterir
- Seçilen koordinatları gösterir
- İptal butonu sağlar

**OptimizationDialog** - Optimizasyon parametrelerini ister:
- Seçilen bölge koordinatlarını gösterir
- Türbin ekipman ID giriş alanı
- Hesaplama butonu

#### 4. **Model Sınıfları** (`lib/data/models/pin_model.dart`)

```dart
class OptimizedWindPoint {
  final double latitude;
  final double longitude;
  final double windSpeedMs;
  final double annualProductionKwh;
  final double score;
}

class OptimizationResponse {
  final double totalCapacityMw;
  final double totalAnnualProductionKwh;
  final int turbineCount;
  final List<OptimizedWindPoint> points;
}
```

#### 5. **API Service** (`lib/core/api_service.dart`)

```dart
Future<OptimizationResponse> optimizeWindPlacement({
  required double topLeftLat,
  required double topLeftLon,
  required double bottomRightLat,
  required double bottomRightLon,
  required int equipmentId,
  double minDistanceM = 0.0,
}) async
```

## UI/UX Akışı

### Harita Üzerindeki Görseller

1. **Seçim Modu Aktifken:**
   - Kullanıcı ilk tıklaması: Belirteci "Sol-Üst Köşesini seç" mesajı gösterilir
   - Kullanıcı ikinci tıklaması: Belirteci "Sağ-Alt Köşesini seç" mesajı gösterilir
   - Harita üzerinde: Mavi kenarlı, şeffaf mavi dolu dikdörtgen gösterilir

2. **Optimizasyon Sonrasında:**
   - Haritada her türbin yerleşimi için mavi wind icon marker'ı
   - Hover ederseniz rüzgar hızı ve yıllık üretim tooltip gösterilir

### Uyarı Göstergeleri

- **RegionSelectionIndicator**: Alt tarafta gösterilir, seçim durumunu gösterir
- **OptimizationDialog**: Pop-up dialog ile parametreler istenir
- **SnackBar**: İşlem tamamlanınca kullanıcıya bildirim verilir

## Hata Yönetimi

- Geçersiz koordinatlar: "Lütfen önce bölge seçin" uyarısı
- Geçersiz Equipment ID: "Lütfen geçerli bir ekipman ID girin" uyarısı
- Backend hatası: "Optimizasyon hesaplaması başarısız oldu" mesajı

## Sonraki Adımlar (İsteğe Bağlı İyileştirmeler)

1. **Güneş Paneli Optimizasyonu**: 
   - `/optimization/solar-placement` endpoint'i ekle
   - Similar UI ekle

2. **Sonuç Saklama**:
   - Optimizasyon sonuçlarını kullanıcı veritabanında kaydet
   - Geçmiş optimizasyonları geri getir

3. **Gelişmiş Analiz**:
   - Her türbin için detaylı analiz view'ı
   - Türbin seçiminin ekonomik analizi
   - Şebeke entegrasyonu simülasyonu

4. **Gerçek Zamanlı Veri**:
   - Mevcut rüzgar/sıcaklık verilerini optimize hesaplamasında kullan
   - Weather API'den canlı veri çek

## Test Edilmeş Senaryolar

✅ Bölge seçimi başarıyla kaydediliyor
✅ Harita dikdörtgeni doğru koordinatlarla çiziliyor
✅ Backend ile iletişim başarılı
✅ Sonuç marker'ları haritada gösterilir
✅ Hata durumlarında uygun mesajlar gösterilir

## İlgili Dosyalar

- `frontend/lib/providers/map_provider.dart` - State yönetimi
- `frontend/lib/presentation/screens/map_screen.dart` - Harita ekranı
- `frontend/lib/presentation/widgets/map/map_dialogs.dart` - Dialog ve göstergeler
- `frontend/lib/core/api_service.dart` - API iletişimi
- `frontend/lib/data/models/pin_model.dart` - Veri modelleri
- `backend/routers/optimization.py` - Optimization endpoint'i
