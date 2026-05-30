// Faz 1 — Tek Kaynak. Backend `province_analysis` tablosundan beslenen
// `/analysis/*` endpoint'lerine bağlanır.
//
// - `/analysis/provinces?type=wind|solar|hydro&horizon=1m|3m|6m|yearly[&limit=N]`
// - `/analysis/province/{name}` → 3 kaynak × 4 pencere detay
// - `/analysis/choropleth/{metric}?horizon=6m` → { province_name → score }
//
// Faz 2'de Önerilen Bölgeler, İl Analizi ve Raporlar choropleth'i bu servise
// taşınacak (mevcut `weather_service.dart` / `recommendation_service.dart`
// endpoint'leri geçici uyumluluk için duruyor).

import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

/// Kaynak tipi — backend enum'uyla birebir.
enum AnalysisResourceType { wind, solar, hydro }

String _resourceTypeLabel(AnalysisResourceType t) =>
    t.toString().split('.').last;

/// Zaman penceresi — backend enum'uyla birebir (`1m` | `3m` | `6m` | `yearly`).
enum AnalysisHorizon { m1, m3, m6, yearly }

String _horizonLabel(AnalysisHorizon h) {
  switch (h) {
    case AnalysisHorizon.m1:
      return '1m';
    case AnalysisHorizon.m3:
      return '3m';
    case AnalysisHorizon.m6:
      return '6m';
    case AnalysisHorizon.yearly:
      return 'yearly';
  }
}

class ProvinceAnalysisItem {
  final String provinceName;
  final String resourceType; // "wind" | "solar" | "hydro"
  final double? score1m;
  final double? score3m;
  final double? score6m;
  final double? scoreYearly;
  final double? avgWindSpeed;
  final double? avgSolarRadiation;
  final double? avgTemperature;
  final double? capacityFactor;
  final int? sampleCount;
  final DateTime? computedAt;

  const ProvinceAnalysisItem({
    required this.provinceName,
    required this.resourceType,
    this.score1m,
    this.score3m,
    this.score6m,
    this.scoreYearly,
    this.avgWindSpeed,
    this.avgSolarRadiation,
    this.avgTemperature,
    this.capacityFactor,
    this.sampleCount,
    this.computedAt,
  });

  /// Verilen horizon'a göre ilgili skoru döner — UI sıralama/gösterimi için.
  double? scoreFor(AnalysisHorizon h) {
    switch (h) {
      case AnalysisHorizon.m1:
        return score1m;
      case AnalysisHorizon.m3:
        return score3m;
      case AnalysisHorizon.m6:
        return score6m;
      case AnalysisHorizon.yearly:
        return scoreYearly;
    }
  }

  factory ProvinceAnalysisItem.fromJson(Map<String, dynamic> json) {
    final scores = (json['scores'] as Map?) ?? const {};
    final raw = (json['raw'] as Map?) ?? const {};
    double? d(dynamic v) => (v as num?)?.toDouble();
    return ProvinceAnalysisItem(
      provinceName: json['province_name'] as String,
      resourceType: json['resource_type'] as String,
      score1m: d(scores['1m']),
      score3m: d(scores['3m']),
      score6m: d(scores['6m']),
      scoreYearly: d(scores['yearly']),
      avgWindSpeed: d(raw['avg_wind_speed']),
      avgSolarRadiation: d(raw['avg_solar_radiation']),
      avgTemperature: d(raw['avg_temperature']),
      capacityFactor: d(raw['capacity_factor']),
      sampleCount: (json['sample_count'] as num?)?.toInt(),
      computedAt: json['computed_at'] != null
          ? DateTime.tryParse(json['computed_at'] as String)
          : null,
    );
  }
}

/// `/analysis/provinces` yanıtı — liste + metadata.
class ProvinceAnalysisList {
  final AnalysisResourceType resourceType;
  final AnalysisHorizon horizon;
  final int count;
  final List<ProvinceAnalysisItem> items;

  const ProvinceAnalysisList({
    required this.resourceType,
    required this.horizon,
    required this.count,
    required this.items,
  });

  bool get isEmpty => items.isEmpty;
}

/// `/analysis/choropleth/{metric}` yanıtı.
class AnalysisChoropleth {
  final String metric;
  final String horizon;
  final int count;
  final double? min;
  final double? max;
  final Map<String, double?> scores;

  const AnalysisChoropleth({
    required this.metric,
    required this.horizon,
    required this.count,
    required this.min,
    required this.max,
    required this.scores,
  });
}

/// `/analysis/province/{name}` yanıtı.
class ProvinceDetail {
  final String provinceName;
  final Map<String, ProvinceAnalysisItem> byResource;

  const ProvinceDetail({
    required this.provinceName,
    required this.byResource,
  });

  ProvinceAnalysisItem? get wind => byResource['wind'];
  ProvinceAnalysisItem? get solar => byResource['solar'];
  ProvinceAnalysisItem? get hydro => byResource['hydro'];
}

class AnalysisService extends BaseService {
  AnalysisService(super.storageService);

  /// Belirli kaynak + pencere için iller (skora göre azalan).
  ///
  /// [limit] null ise 81 ilin tamamı döner.
  Future<ProvinceAnalysisList> fetchProvinces({
    required AnalysisResourceType type,
    AnalysisHorizon horizon = AnalysisHorizon.m6,
    int? limit,
  }) async {
    final qp = <String, String>{
      'type': _resourceTypeLabel(type),
      'horizon': _horizonLabel(horizon),
      if (limit != null) 'limit': '$limit',
    };
    final uri = Uri.parse('$baseUrl/analysis/provinces').replace(
      queryParameters: qp,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/provinces');
    }
    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems
        .map((e) => ProvinceAnalysisItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return ProvinceAnalysisList(
      resourceType: type,
      horizon: horizon,
      count: (data['count'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }

  /// Tek il detay — 3 kaynak × 4 pencere skor + ham metrik.
  Future<ProvinceDetail> fetchProvinceDetail(String name) async {
    final uri = Uri.parse('$baseUrl/analysis/province/$name');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/province/$name');
    }
    final resourcesRaw = (data['resources'] as Map?) ?? const {};
    final byResource = <String, ProvinceAnalysisItem>{};
    resourcesRaw.forEach((key, value) {
      if (value is Map) {
        byResource[key.toString()] =
            ProvinceAnalysisItem.fromJson(Map<String, dynamic>.from(value));
      }
    });
    return ProvinceDetail(
      provinceName: data['province_name']?.toString() ?? name,
      byResource: byResource,
    );
  }

  /// Choropleth map — il adı → skor.
  Future<AnalysisChoropleth> fetchChoropleth({
    required AnalysisResourceType metric,
    AnalysisHorizon horizon = AnalysisHorizon.m6,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/analysis/choropleth/${_resourceTypeLabel(metric)}',
    ).replace(queryParameters: {'horizon': _horizonLabel(horizon)});
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/choropleth');
    }
    final scoresRaw = (data['scores'] as Map?) ?? const {};
    final scores = <String, double?>{};
    scoresRaw.forEach((k, v) {
      scores[k.toString()] = (v as num?)?.toDouble();
    });
    return AnalysisChoropleth(
      metric: data['metric']?.toString() ?? _resourceTypeLabel(metric),
      horizon: data['horizon']?.toString() ?? _horizonLabel(horizon),
      count: (data['count'] as num?)?.toInt() ?? 0,
      min: (data['min'] as num?)?.toDouble(),
      max: (data['max'] as num?)?.toDouble(),
      scores: scores,
    );
  }

  // ── R1 Landing/Region Data ────────────────────────────────────────────────

  /// /analysis/landing — TR genel + 7 bölge özeti + top-N il
  Future<LandingData> fetchLanding({int topN = 10}) async {
    final uri = Uri.parse('$baseUrl/analysis/landing').replace(
      queryParameters: {'top_n': '$topN'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/landing');
    }
    return LandingData.fromJson(Map<String, dynamic>.from(data));
  }

  /// /analysis/region/{id} — Tek bölge detay + il listesi pivot
  Future<RegionDetailData> fetchRegionDetail(String regionId) async {
    final uri = Uri.parse('$baseUrl/analysis/region/$regionId');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/region/$regionId');
    }
    return RegionDetailData.fromJson(Map<String, dynamic>.from(data));
  }

  /// /analysis/province/{name}/climate — İl aylık iklim serileri
  Future<ClimateSeries> fetchProvinceClimate(String name) async {
    final uri = Uri.parse('$baseUrl/analysis/province/$name/climate');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/province/$name/climate');
    }
    return ClimateSeries.fromJson(Map<String, dynamic>.from(data));
  }

  /// /analysis/province/{name}/districts — İlçe granüler skor + best spots
  Future<ProvinceDistrictsData> fetchProvinceDistricts(String name) async {
    final uri = Uri.parse('$baseUrl/analysis/province/$name/districts');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/province/$name/districts');
    }
    return ProvinceDistrictsData.fromJson(Map<String, dynamic>.from(data));
  }

  /// Aşama 3.D — Geçmiş günlük veriden gelecek tahmini.
  ///
  /// [metric]: 'wind_speed' | 'shortwave_radiation' | 'temperature'
  /// [horizonDays]: 30 | 90 | 180 | 365
  Future<ProjectionResponse> fetchProjection({
    required String province,
    String metric = 'wind_speed',
    int horizonDays = 90,
  }) async {
    final uri = Uri.parse('$baseUrl/analysis/projection').replace(
      queryParameters: {
        'province': province,
        'metric': metric,
        'horizon_days': '$horizonDays',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /analysis/projection');
    }
    return ProjectionResponse.fromJson(Map<String, dynamic>.from(data));
  }
}

/// Tek bir tahmin noktası.
class ProjectionPoint {
  final DateTime date;
  final double value;
  final double lower;
  final double upper;

  const ProjectionPoint({
    required this.date,
    required this.value,
    required this.lower,
    required this.upper,
  });

  factory ProjectionPoint.fromJson(Map<String, dynamic> json) {
    return ProjectionPoint(
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num).toDouble(),
      lower: (json['lower'] as num).toDouble(),
      upper: (json['upper'] as num).toDouble(),
    );
  }
}

/// /analysis/projection yanıtı.
class ProjectionResponse {
  final String province;
  final String metric;
  final int horizonDays;
  final int historyDays;
  final int historyYears;
  final String method;
  final double? historicalAvg;
  final double? annualTrendPct;
  final List<ProjectionPoint> points;
  final String disclaimer;

  const ProjectionResponse({
    required this.province,
    required this.metric,
    required this.horizonDays,
    required this.historyDays,
    required this.historyYears,
    required this.method,
    required this.historicalAvg,
    required this.annualTrendPct,
    required this.points,
    required this.disclaimer,
  });

  factory ProjectionResponse.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List? ?? const [])
        .map((e) => ProjectionPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ProjectionResponse(
      province: json['province']?.toString() ?? '',
      metric: json['metric']?.toString() ?? '',
      horizonDays: (json['horizon_days'] as num?)?.toInt() ?? 0,
      historyDays: (json['history_days'] as num?)?.toInt() ?? 0,
      historyYears: (json['history_years'] as num?)?.toInt() ?? 0,
      method: json['method']?.toString() ?? '',
      historicalAvg: (json['historical_avg'] as num?)?.toDouble(),
      annualTrendPct: (json['annual_trend_pct'] as num?)?.toDouble(),
      points: pts,
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}

// ── R1 Landing DTO'ları ──────────────────────────────────────────────────────

/// TR genel istatistikleri (tr_stats.json'dan).
class TrStats {
  final int totalInstalledMw;
  final int renewableMw;
  final double renewableShare;
  final int solarMw;
  final int windMw;
  final int hydroMw;
  final int geothermalMw;
  final int biomassMw;
  final int annualProductionGwh;
  final int renewableProductionGwh;
  final int co2AvoidedKtPerYear;
  final int target2035Mw;
  final double target2035RenewableShare;
  final int solarPotentialMw;
  final int windPotentialMw;
  final int hydroPotentialMw;
  final int technicalPotentialMw;
  final List<LandingTrendPoint> capacityTrend;

  const TrStats({
    required this.totalInstalledMw,
    required this.renewableMw,
    required this.renewableShare,
    required this.solarMw,
    required this.windMw,
    required this.hydroMw,
    required this.geothermalMw,
    required this.biomassMw,
    required this.annualProductionGwh,
    required this.renewableProductionGwh,
    required this.co2AvoidedKtPerYear,
    required this.target2035Mw,
    required this.target2035RenewableShare,
    required this.solarPotentialMw,
    required this.windPotentialMw,
    required this.hydroPotentialMw,
    required this.technicalPotentialMw,
    required this.capacityTrend,
  });

  factory TrStats.fromJson(Map<String, dynamic> j) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return TrStats(
      totalInstalledMw: i(j['totalInstalledMw']),
      renewableMw: i(j['renewableMw']),
      renewableShare: d(j['renewableShare']),
      solarMw: i(j['solarMw']),
      windMw: i(j['windMw']),
      hydroMw: i(j['hydroMw']),
      geothermalMw: i(j['geothermalMw']),
      biomassMw: i(j['biomassMw']),
      annualProductionGwh: i(j['annualProductionGwh']),
      renewableProductionGwh: i(j['renewableProductionGwh']),
      co2AvoidedKtPerYear: i(j['co2AvoidedKtPerYear']),
      target2035Mw: i(j['target2035Mw']),
      target2035RenewableShare: d(j['target2035RenewableShare']),
      solarPotentialMw: i(j['solarPotentialMw']),
      windPotentialMw: i(j['windPotentialMw']),
      hydroPotentialMw: i(j['hydroPotentialMw']),
      technicalPotentialMw: i(j['technicalPotentialMw']),
      capacityTrend: ((j['capacityTrend'] as List?) ?? const [])
          .map((e) => LandingTrendPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Yıllık trend noktası (kurulu güç GW).
class LandingTrendPoint {
  final int year;
  final double total;
  final double renewable;

  const LandingTrendPoint({
    required this.year,
    required this.total,
    required this.renewable,
  });

  factory LandingTrendPoint.fromJson(Map<String, dynamic> j) => LandingTrendPoint(
        year: (j['year'] as num).toInt(),
        total: (j['total'] as num).toDouble(),
        renewable: (j['renewable'] as num).toDouble(),
      );
}

/// 7 bölge meta + climatology avg_scores.
class RegionMeta {
  final String id;
  final String name;
  final String color;
  final int provincesCount;
  final List<String> provinces;
  final int capacityMw;
  final int annualGwh;
  final double irradiance;
  final double windSpeed;
  final int precipitation;
  final String climateNote;
  final List<String> bestFor;
  final String topResource;
  final String description;
  final Map<String, double?> avgScores; // {"wind": .., "solar": .., "hydro": ..}

  const RegionMeta({
    required this.id,
    required this.name,
    required this.color,
    required this.provincesCount,
    required this.provinces,
    required this.capacityMw,
    required this.annualGwh,
    required this.irradiance,
    required this.windSpeed,
    required this.precipitation,
    required this.climateNote,
    required this.bestFor,
    required this.topResource,
    required this.description,
    required this.avgScores,
  });

  factory RegionMeta.fromJson(Map<String, dynamic> j) {
    final avg = (j['avg_scores'] as Map?) ?? const {};
    return RegionMeta(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      color: j['color']?.toString() ?? '#888888',
      provincesCount: (j['provincesCount'] as num?)?.toInt() ?? 0,
      provinces: ((j['provinces'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      capacityMw: (j['capacityMw'] as num?)?.toInt() ?? 0,
      annualGwh: (j['annualGwh'] as num?)?.toInt() ?? 0,
      irradiance: (j['irradiance'] as num?)?.toDouble() ?? 0,
      windSpeed: (j['windSpeed'] as num?)?.toDouble() ?? 0,
      precipitation: (j['precipitation'] as num?)?.toInt() ?? 0,
      climateNote: j['climateNote']?.toString() ?? '',
      bestFor: ((j['bestFor'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      topResource: j['topResource']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      avgScores: {
        'wind': (avg['wind'] as num?)?.toDouble(),
        'solar': (avg['solar'] as num?)?.toDouble(),
        'hydro': (avg['hydro'] as num?)?.toDouble(),
      },
    );
  }
}

/// Top-N il listesinde tek bir il.
class TopProvinceItem {
  final String provinceName;
  final double score;
  final double? capacityFactor;
  final double? avgWindSpeed;
  final double? avgGhi;

  const TopProvinceItem({
    required this.provinceName,
    required this.score,
    this.capacityFactor,
    this.avgWindSpeed,
    this.avgGhi,
  });

  factory TopProvinceItem.fromJson(Map<String, dynamic> j) => TopProvinceItem(
        provinceName: j['province_name']?.toString() ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
        capacityFactor: (j['capacity_factor'] as num?)?.toDouble(),
        avgWindSpeed: (j['avg_wind_speed'] as num?)?.toDouble(),
        avgGhi: (j['avg_ghi'] as num?)?.toDouble(),
      );
}

/// Tüm kaynaklar arasında en yüksek skorlu illerin (province, top_resource, score).
class OverallTopItem {
  final String provinceName;
  final String topResource; // "wind" | "solar" | "hydro"
  final double score;

  const OverallTopItem({
    required this.provinceName,
    required this.topResource,
    required this.score,
  });

  factory OverallTopItem.fromJson(Map<String, dynamic> j) => OverallTopItem(
        provinceName: j['province_name']?.toString() ?? '',
        topResource: j['top_resource']?.toString() ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

/// /analysis/landing tam yanıtı.
class LandingData {
  final TrStats trStats;
  final List<RegionMeta> regions;
  final Map<String, List<TopProvinceItem>> topByResource;
  final List<OverallTopItem> overallTop;

  const LandingData({
    required this.trStats,
    required this.regions,
    required this.topByResource,
    required this.overallTop,
  });

  factory LandingData.fromJson(Map<String, dynamic> j) {
    final topRaw = (j['top_provinces'] as Map?) ?? const {};
    final topMap = <String, List<TopProvinceItem>>{};
    topRaw.forEach((key, value) {
      if (value is List) {
        topMap[key.toString()] = value
            .map((e) =>
                TopProvinceItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    });
    return LandingData(
      trStats: TrStats.fromJson(Map<String, dynamic>.from(j['tr_stats'] as Map)),
      regions: ((j['regions'] as List?) ?? const [])
          .map((e) => RegionMeta.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      topByResource: topMap,
      overallTop: ((j['overall_top'] as List?) ?? const [])
          .map((e) => OverallTopItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// İl bazlı kaynak skoru — region detail provinces içinde.
class RegionProvinceItem {
  final String provinceName;
  final double? lat;
  final double? lon;
  final double? windScore;
  final double? solarScore;
  final double? hydroScore;
  final double? windCapacityFactor;
  final double? solarCapacityFactor;
  final double? hydroCapacityFactor;

  const RegionProvinceItem({
    required this.provinceName,
    this.lat,
    this.lon,
    this.windScore,
    this.solarScore,
    this.hydroScore,
    this.windCapacityFactor,
    this.solarCapacityFactor,
    this.hydroCapacityFactor,
  });

  factory RegionProvinceItem.fromJson(Map<String, dynamic> j) {
    double? s(String key) {
      final r = j[key];
      if (r is Map) return (r['score'] as num?)?.toDouble();
      return null;
    }
    double? cf(String key) {
      final r = j[key];
      if (r is Map) return (r['capacity_factor'] as num?)?.toDouble();
      return null;
    }
    return RegionProvinceItem(
      provinceName: j['province_name']?.toString() ?? '',
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      windScore: s('wind'),
      solarScore: s('solar'),
      hydroScore: s('hydro'),
      windCapacityFactor: cf('wind'),
      solarCapacityFactor: cf('solar'),
      hydroCapacityFactor: cf('hydro'),
    );
  }

  String get bestResource {
    final scores = {
      'wind': windScore ?? 0,
      'solar': solarScore ?? 0,
      'hydro': hydroScore ?? 0,
    };
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double get bestScore =>
      [windScore ?? 0, solarScore ?? 0, hydroScore ?? 0]
          .reduce((a, b) => a > b ? a : b);
}

/// 12 aylık iklim serileri (climate_aggregate_service'ten gelen).
class ClimateSeries {
  final List<double> irradiance;
  final List<double> windSpeed;
  final List<double> precipitation;
  final List<double> temperature;
  final List<double> cloudCover;
  final List<double> sunshineHours;
  final List<RiverDischargePoint> riverDischarge;
  final WindRose windRose;
  final String source; // "db" | "mock_region:..." | "hybrid_..."

  const ClimateSeries({
    required this.irradiance,
    required this.windSpeed,
    required this.precipitation,
    required this.temperature,
    required this.cloudCover,
    required this.sunshineHours,
    required this.riverDischarge,
    required this.windRose,
    required this.source,
  });

  factory ClimateSeries.fromJson(Map<String, dynamic> j) {
    List<double> arr(dynamic v) =>
        (v as List? ?? const []).map((e) => (e as num).toDouble()).toList();
    return ClimateSeries(
      irradiance: arr(j['irradiance']),
      windSpeed: arr(j['wind_speed']),
      precipitation: arr(j['precipitation']),
      temperature: arr(j['temperature']),
      cloudCover: arr(j['cloud_cover']),
      sunshineHours: arr(j['sunshine_hours']),
      riverDischarge: ((j['river_discharge'] as List?) ?? const [])
          .map((e) => RiverDischargePoint.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      windRose: WindRose.fromJson(
          Map<String, dynamic>.from(j['wind_rose'] as Map? ?? const {})),
      source: j['source']?.toString() ?? 'unknown',
    );
  }
}

class RiverDischargePoint {
  final double mean;
  final double min;
  final double max;
  const RiverDischargePoint({required this.mean, required this.min, required this.max});
  factory RiverDischargePoint.fromJson(Map<String, dynamic> j) => RiverDischargePoint(
        mean: (j['mean'] as num?)?.toDouble() ?? 0,
        min: (j['min'] as num?)?.toDouble() ?? 0,
        max: (j['max'] as num?)?.toDouble() ?? 0,
      );
}

class WindRose {
  final String dominant;
  final Map<String, double> histogram; // 8 bin: N/NE/E/SE/S/SW/W/NW

  const WindRose({required this.dominant, required this.histogram});
  factory WindRose.fromJson(Map<String, dynamic> j) {
    final hist = <String, double>{};
    final raw = j['histogram'] as Map? ?? const {};
    raw.forEach((k, v) {
      hist[k.toString()] = (v as num?)?.toDouble() ?? 0;
    });
    return WindRose(
      dominant: j['dominant']?.toString() ?? 'NW',
      histogram: hist,
    );
  }
}

// ── İlçe granüler skor DTO'ları (/analysis/province/{name}/districts) ────────

/// Bir ilçenin 3 kaynak skoru.
class DistrictScore {
  final String name;
  final double lat;
  final double lon;
  final double windScore;
  final double solarScore;
  final double hydroScore;
  final String bestResource;
  final double bestScore;
  final int estimatedMw;

  const DistrictScore({
    required this.name,
    required this.lat,
    required this.lon,
    required this.windScore,
    required this.solarScore,
    required this.hydroScore,
    required this.bestResource,
    required this.bestScore,
    required this.estimatedMw,
  });

  factory DistrictScore.fromJson(Map<String, dynamic> j) {
    final scores = (j['scores'] as Map?) ?? const {};
    double s(String k) => (scores[k] as num?)?.toDouble() ?? 0;
    return DistrictScore(
      name: j['name']?.toString() ?? '',
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lon: (j['lon'] as num?)?.toDouble() ?? 0,
      windScore: s('wind'),
      solarScore: s('solar'),
      hydroScore: s('hydro'),
      bestResource: j['best_resource']?.toString() ?? 'solar',
      bestScore: (j['best_score'] as num?)?.toDouble() ?? 0,
      estimatedMw: (j['estimated_mw'] as num?)?.toInt() ?? 0,
    );
  }

  double scoreFor(String resource) => switch (resource) {
        'wind' => windScore,
        'solar' => solarScore,
        'hydro' => hydroScore,
        _ => 0,
      };
}

/// Bir kaynak için "en iyi saha" — kaynak-spesifik ek alanlar dynamic map'te.
class BestSpot {
  final String name;
  final double lat;
  final double lon;
  final double score;
  final int estimatedMw;
  // Kaynak-spesifik (solar: irradiance/slope/panelArea, wind: windSpeed/hub, hydro: flow/head)
  final Map<String, dynamic> extra;

  const BestSpot({
    required this.name,
    required this.lat,
    required this.lon,
    required this.score,
    required this.estimatedMw,
    required this.extra,
  });

  factory BestSpot.fromJson(Map<String, dynamic> j) {
    const known = {'name', 'lat', 'lon', 'score', 'estimated_mw'};
    return BestSpot(
      name: j['name']?.toString() ?? '',
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lon: (j['lon'] as num?)?.toDouble() ?? 0,
      score: (j['score'] as num?)?.toDouble() ?? 0,
      estimatedMw: (j['estimated_mw'] as num?)?.toInt() ?? 0,
      extra: {
        for (final e in j.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }
}

/// /analysis/province/{name}/districts yanıtı.
class ProvinceDistrictsData {
  final String province;
  final int districtCount;
  final List<DistrictScore> districts;
  final Map<String, List<BestSpot>> bestSpots; // {solar, wind, hydro}

  const ProvinceDistrictsData({
    required this.province,
    required this.districtCount,
    required this.districts,
    required this.bestSpots,
  });

  factory ProvinceDistrictsData.fromJson(Map<String, dynamic> j) {
    final spotsRaw = (j['best_spots'] as Map?) ?? const {};
    final spots = <String, List<BestSpot>>{};
    spotsRaw.forEach((key, value) {
      if (value is List) {
        spots[key.toString()] = value
            .map((e) => BestSpot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    });
    return ProvinceDistrictsData(
      province: j['province']?.toString() ?? '',
      districtCount: (j['district_count'] as num?)?.toInt() ?? 0,
      districts: ((j['districts'] as List?) ?? const [])
          .map((e) => DistrictScore.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bestSpots: spots,
    );
  }
}

/// /analysis/region/{id} yanıtı.
class RegionDetailData {
  final RegionMeta region;
  final List<RegionProvinceItem> provinces;
  final ClimateSeries climate;

  const RegionDetailData({
    required this.region,
    required this.provinces,
    required this.climate,
  });

  factory RegionDetailData.fromJson(Map<String, dynamic> j) {
    return RegionDetailData(
      region: RegionMeta.fromJson(Map<String, dynamic>.from(j['region'] as Map)),
      provinces: ((j['provinces'] as List?) ?? const [])
          .map((e) =>
              RegionProvinceItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      climate: ClimateSeries.fromJson(
          Map<String, dynamic>.from(j['climate'] as Map? ?? const {})),
    );
  }
}
