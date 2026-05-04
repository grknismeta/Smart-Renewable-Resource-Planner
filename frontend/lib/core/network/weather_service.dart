import 'package:http/http.dart' as http;
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/core/network/api_client.dart';

// ── In-memory TTL cache ────────────────────────────────────────────────────
class _CacheEntry {
  final http.Response response;
  final DateTime expiry;
  _CacheEntry(this.response, this.expiry);
  bool get isValid => DateTime.now().isBefore(expiry);
}

class WeatherService extends BaseService {
  WeatherService(super.storageService);

  final Map<String, _CacheEntry> _cache = {};

  static const _kSummaryTtl  = Duration(minutes: 5);   // Saatlik güncellenen veriler
  static const _kTrendTtl    = Duration(minutes: 30);  // Tarihsel / az değişen
  static const _kStaticTtl   = Duration(hours: 1);     // Yıllar listesi vb.

  Future<http.Response> _cachedGet(Uri uri, {Duration ttl = _kSummaryTtl}) async {
    final key = uri.toString();
    final entry = _cache[key];
    if (entry != null && entry.isValid) return entry.response;
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      _cache[key] = _CacheEntry(response, DateTime.now().add(ttl));
    }
    return response;
  }

  /// Belirli bir URL prefix'ine ait tüm cache girdilerini temizler.
  void invalidateCache([String? prefix]) {
    if (prefix == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((k, _) => k.contains(prefix));
    }
  }

  Future<List<CityWeatherSummary>> fetchWeatherSummary({
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/summary',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await _cachedGet(uri);
    
    final data = processResponse(response);
    if (data is List) {
       return data.map((json) => CityWeatherSummary.fromJson(json)).toList();
    }
    throw Exception('Hava durumu verisi alınamadı');
  }

  Future<List<CityWeatherData>> fetchWeatherForTime(DateTime time) async {
    final timestamp = time.toIso8601String();
    final response = await http.get(
      Uri.parse('$baseUrl/weather/at-time?timestamp=$timestamp'),
    );
    
    final data = processResponse(response);
    if (data is List) {
        return data.map((json) => CityWeatherData.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<CityWeatherData>> fetchCityHourly(
    String cityName, {
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/cities/$cityName/hourly',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    
    final data = processResponse(response);
    if (data is List) {
       return data.map((e) => CityWeatherData.fromJson(e)).toList();
    }
    throw Exception(
      'Şehir saatlik verisi alınamadı (status: ${response.statusCode})',
    );
  }

  Future<List<IrradianceData>> fetchCityIrradiance(
    String cityName, {
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/cities/$cityName/hourly',
    ).replace(queryParameters: {'hours': '$hours'});

    final response = await http.get(uri);

    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => IrradianceData.fromJson(e)).toList();
    }
    throw Exception(
      'Işınım verisi alınamadı (status: ${response.statusCode})',
    );
  }

  Future<List<ProvinceSummary>> fetchProvinceSummary({
    int hours = 168,
    String? mode,
    String? season,
  }) async {
    final params = <String, String>{'hours': '$hours'};
    if (mode != null) params['mode'] = mode;
    if (season != null) params['season'] = season;
    final uri = Uri.parse(
      '$baseUrl/weather/province-summary',
    ).replace(queryParameters: params);
    final response = await _cachedGet(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => ProvinceSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<DistrictSummary>> fetchDistrictSummary({
    String? province,
    String? provinceCode,
    int hours = 168,
    String? mode,
    String? season,
  }) async {
    final params = <String, String>{'hours': '$hours'};
    if (provinceCode != null) {
      params['province_code'] = provinceCode;
    } else if (province != null) {
      params['province'] = province;
    }
    if (mode != null) params['mode'] = mode;
    if (season != null) params['season'] = season;
    final uri = Uri.parse(
      '$baseUrl/weather/district-summary',
    ).replace(queryParameters: params);
    final response = await _cachedGet(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => DistrictSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<RegionSummary>> fetchRegionSummary({
    int hours = 168,
    String? mode,
    String? season,
  }) async {
    final params = <String, String>{'hours': '$hours'};
    if (mode != null) params['mode'] = mode;
    if (season != null) params['season'] = season;
    final uri = Uri.parse(
      '$baseUrl/weather/region-summary',
    ).replace(queryParameters: params);
    final response = await _cachedGet(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => RegionSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchBestSolarCities({
    int limit = 1000,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/best-solar',
    ).replace(queryParameters: {'limit': '$limit'});

    final response = await _cachedGet(uri);
    
    final data = processResponse(response);
     if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
     throw Exception(
      'En iyi güneş şehirleri alınamadı (status: ${response.statusCode})',
    );
  }

  /// Animasyon için kullanılabilir veri tarih aralığını döndürür.
  /// { daily_min, daily_max, hourly_min, hourly_max }
  Future<Map<String, dynamic>> fetchAnimationRange() async {
    final response = await _cachedGet(
      Uri.parse('$baseUrl/weather/animation/range'),
      ttl: _kTrendTtl,
    );
    final data = processResponse(response);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Animasyon aralığı alınamadı');
  }

  /// Animasyon frame verisi döndürür.
  ///
  /// [start] / [end]: "YYYY-MM-DD"
  /// [metric]: "wind" | "temperature" | "radiation"
  /// [interval]: "daily" | "hourly"
  /// [format]: "districts" (default, 1.A2 — frame.vals = {"İl|İlçe": val}) |
  ///           "points" (legacy, frame.pts = [[lat, lon, val, name]])
  ///
  /// 60 sn timeout — saatlik mod + geniş tarih aralığı 10+ MB yanıt üretebilir.
  Future<Map<String, dynamic>> fetchAnimationData({
    required String start,
    required String end,
    required String metric,
    required String interval,
    String format = 'districts',
  }) async {
    final uri = Uri.parse('$baseUrl/weather/animation').replace(
      queryParameters: {
        'start': start,
        'end': end,
        'metric': metric,
        'interval': interval,
        'format': format,
      },
    );
    final response =
        await http.get(uri).timeout(const Duration(seconds: 60));
    final data = processResponse(response);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Animasyon verisi alınamadı');
  }

  // ── Rapor Dashboard metodları ──────────────────────────────────────────────

  /// DB'de kayıtlı yıllar listesi (zaman aralığı seçici için).
  Future<List<int>> fetchAvailableYears() async {
    final response = await _cachedGet(
      Uri.parse('$baseUrl/weather/available-years'),
      ttl: _kStaticTtl,
    );
    final data = processResponse(response);
    if (data is List) return data.cast<int>();
    return [];
  }

  /// Aylık veya günlük trend verisi.
  ///
  /// [metric]: "solar" | "wind" | "temperature"
  /// [month]: null → 12 aylık özet; 1-12 → o ayın günlük özeti
  Future<List<TrendPoint>> fetchMonthlyTrend(
    String city,
    String metric,
    int year, {
    int? month,
  }) async {
    final params = <String, String>{
      'city': city,
      'metric': metric,
      'year': '$year',
    };
    if (month != null) params['month'] = '$month';

    final uri = Uri.parse(
      '$baseUrl/weather/monthly-trend',
    ).replace(queryParameters: params);
    final response = await _cachedGet(uri, ttl: _kTrendTtl);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => TrendPoint.fromJson(e)).toList();
    }
    return [];
  }

  /// Tarih aralığı bazlı il özeti (Yıllık / Özel aralık modları için).
  Future<List<ProvinceSummary>> fetchProvinceSummaryByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    String fmtDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(
      '$baseUrl/weather/province-summary-range',
    ).replace(queryParameters: {'start': fmtDate(start), 'end': fmtDate(end)});
    final response = await _cachedGet(uri, ttl: _kTrendTtl);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => ProvinceSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<CitySolarSummary>> fetchSolarSummary({int hours = 168}) async {
    final summaries = await fetchWeatherSummary(hours: hours);

    return summaries.map((weather) {
      final avgRadiationWm2 =
          weather.totalRadiation != null && weather.recordCount > 0
          ? weather.totalRadiation! / weather.recordCount
          : null;

      final dailyKwhM2 = avgRadiationWm2 != null
          ? (avgRadiationWm2 * 24 * 365) / 1000.0
          : null;

      return CitySolarSummary(
        cityName: weather.cityName,
        latitude: weather.lat,
        longitude: weather.lon,
        lastUpdate: weather.lastUpdate,
        recordCount: weather.recordCount,
        avgShortwaveRadiation: avgRadiationWm2,
        avgDirectRadiation: null,
        avgDiffuseRadiation: null,
        totalDailyIrradianceKwhM2: dailyKwhM2,
        avgCloudCover: null,
        avgTemperature: weather.avgTemperature,
      );
    }).toList();
  }

  /// Arka plan veri toplayıcısının sağlık durumunu döndürür.
  /// {healthy, minutesAgo, records48h}
  Future<Map<String, dynamic>> fetchCollectorStatus() async {
    final uri = Uri.parse('$baseUrl/weather/collector-status');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(processResponse(response));
    }
    return {'healthy': false, 'minutes_ago': null, 'records_48h': 0};
  }

  /// Choropleth harita verisi: tüm ilçeler için {wind, solar, temp} değerleri.
  /// key: "İl|İlçe" formatında composite key.
  ///
  /// [mode]:
  ///   - 'current' *(yeni, default)* — her ilçenin kendi son saati (anlık snapshot)
  ///   - 'yearly'                   — 365 gün ortalaması; solar için günlük peak avg
  ///   - 'season'                   — 365 gün + mevsim ay filtresi
  ///   - 'latest' | 'average'       — legacy (current ≡ latest)
  /// [season]: mode='season' ise zorunlu (winter|spring|summer|autumn).
  Future<Map<String, dynamic>> fetchDistrictChoropleth({
    int hours = 720,
    String mode = 'current',
    String? season,
  }) async {
    final params = <String, String>{'hours': '$hours', 'mode': mode};
    if (season != null) params['season'] = season;
    final uri = Uri.parse('$baseUrl/weather/district-choropleth')
        .replace(queryParameters: params);
    // current/latest: 5 dk cache (son saat sık güncellenir)
    // yearly/season: 60 dk cache (uzun pencere, güncelleme frekansı düşük)
    // average: 10 dk cache
    final Duration ttl;
    if (mode == 'current' || mode == 'latest') {
      ttl = const Duration(minutes: 5);
    } else if (mode == 'yearly' || mode == 'season') {
      ttl = const Duration(minutes: 60);
    } else {
      ttl = const Duration(minutes: 10);
    }
    final response = await _cachedGet(uri, ttl: ttl);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(processResponse(response));
    }
    return {};
  }
}
