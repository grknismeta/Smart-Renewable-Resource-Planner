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
}
