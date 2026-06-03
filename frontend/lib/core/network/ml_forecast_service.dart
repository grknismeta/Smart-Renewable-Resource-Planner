// lib/core/network/ml_forecast_service.dart
//
// Sprint P2 — SARIMAX projeksiyon endpoint'lerine bağlanır.
//
//   GET /ml/project/pin/{id}?years=N            → pin generation forecast
//   GET /ml/project/province/{name}?years=N&resource=&metric=
//                                                → il climatology forecast
//   GET /ml/health                              → dependency check
//
// Backend: backend/app/routers/ml.py + ml_sarimax_service.py
// Yanıt şeması: ml_sarimax_service.forecast_to_dict()

import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

/// Tek bir forecast noktası — aylık.
class MlForecastPoint {
  final DateTime date;
  final double value;
  final double lower;
  final double upper;

  const MlForecastPoint({
    required this.date,
    required this.value,
    required this.lower,
    required this.upper,
  });

  factory MlForecastPoint.fromJson(Map<String, dynamic> j) => MlForecastPoint(
        date: DateTime.parse(j['date'] as String),
        value: (j['value'] as num).toDouble(),
        lower: (j['lower'] as num?)?.toDouble() ?? (j['value'] as num).toDouble(),
        upper: (j['upper'] as num?)?.toDouble() ?? (j['value'] as num).toDouble(),
      );
}

/// SARIMAX forecast yanıtı.
class MlForecastResponse {
  final String target;
  final int horizonMonths;
  final int historyMonths;
  final List<int> order; // [p, d, q]
  final List<int> seasonalOrder; // [P, D, Q, 12]
  final String method; // sarimax_auto | sarimax_default | fallback_seasonal
  final double? mape; // in-sample
  final double? annualTrendPct;
  final List<MlForecastPoint> points;
  final List<MlForecastPoint> historical;

  const MlForecastResponse({
    required this.target,
    required this.horizonMonths,
    required this.historyMonths,
    required this.order,
    required this.seasonalOrder,
    required this.method,
    required this.mape,
    required this.annualTrendPct,
    required this.points,
    required this.historical,
  });

  factory MlForecastResponse.fromJson(Map<String, dynamic> j) {
    List<MlForecastPoint> pts(dynamic raw) => ((raw as List?) ?? const [])
        .map((e) => MlForecastPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    List<int> intList(dynamic raw) =>
        ((raw as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    return MlForecastResponse(
      target: j['target']?.toString() ?? '',
      horizonMonths: (j['horizon_months'] as num?)?.toInt() ?? 0,
      historyMonths: (j['history_months'] as num?)?.toInt() ?? 0,
      order: intList(j['order']),
      seasonalOrder: intList(j['seasonal_order']),
      method: j['method']?.toString() ?? 'unknown',
      mape: (j['mape'] as num?)?.toDouble(),
      annualTrendPct: (j['annual_trend_pct'] as num?)?.toDouble(),
      points: pts(j['points']),
      historical: pts(j['historical']),
    );
  }

  /// Forecast'taki yıllık toplam → {2026: total, 2027: total, ...}
  Map<int, double> annualTotals() {
    final m = <int, double>{};
    for (final p in points) {
      m[p.date.year] = (m[p.date.year] ?? 0) + p.value;
    }
    return m;
  }

  /// Tüm noktalardan global min/max — chart Y-range için.
  (double, double) valueRange({bool includeBands = true}) {
    final all = [
      ...historical.map((p) => p.value),
      ...points.map((p) => p.value),
      if (includeBands) ...points.map((p) => p.lower),
      if (includeBands) ...points.map((p) => p.upper),
    ];
    if (all.isEmpty) return (0, 1);
    var mn = all.first;
    var mx = all.first;
    for (final v in all) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    return (mn, mx);
  }
}

/// Tek bir iklim senaryosu serisi (baseline | rcp45 | rcp85).
class MlScenarioSeries {
  final String scenario;
  final String label;
  final String description;
  final String color; // "#RRGGBB"
  final double endDeltaPct;
  final List<MlForecastPoint> points; // value-only (lower/upper yok)

  const MlScenarioSeries({
    required this.scenario,
    required this.label,
    required this.description,
    required this.color,
    required this.endDeltaPct,
    required this.points,
  });

  factory MlScenarioSeries.fromJson(Map<String, dynamic> j) {
    final pts = ((j['points'] as List?) ?? const [])
        .map((e) => MlForecastPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return MlScenarioSeries(
      scenario: j['scenario']?.toString() ?? '',
      label: j['label']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      color: j['color']?.toString() ?? '#22D3EE',
      endDeltaPct: (j['end_delta_pct'] as num?)?.toDouble() ?? 0,
      points: pts,
    );
  }
}

/// /ml/scenario/province yanıtı — baseline + RCP serileri.
class MlScenarioResponse {
  final String province;
  final String resource;
  final String metric;
  final int horizonMonths;
  final List<MlScenarioSeries> scenarios;

  const MlScenarioResponse({
    required this.province,
    required this.resource,
    required this.metric,
    required this.horizonMonths,
    required this.scenarios,
  });

  factory MlScenarioResponse.fromJson(Map<String, dynamic> j) {
    final scs = ((j['scenarios'] as List?) ?? const [])
        .map((e) => MlScenarioSeries.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return MlScenarioResponse(
      province: j['province']?.toString() ?? '',
      resource: j['resource']?.toString() ?? '',
      metric: j['metric']?.toString() ?? '',
      horizonMonths: (j['horizon_months'] as num?)?.toInt() ?? 0,
      scenarios: scs,
    );
  }

  /// Tüm senaryo serilerinden global value min/max — chart Y-range.
  (double, double) valueRange() {
    final all = <double>[];
    for (final s in scenarios) {
      all.addAll(s.points.map((p) => p.value));
    }
    if (all.isEmpty) return (0, 1);
    var mn = all.first;
    var mx = all.first;
    for (final v in all) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    return (mn, mx);
  }
}

/// /ml/choropleth yanıtı — tematik harita için {il → değer}.
class MlChoropleth {
  final String metric;
  final String resource;
  final String scenario;
  final String level;
  final int year;
  final double? min;
  final double? max;
  // Scenario-bağımsız renk normalizasyon aralığı (baseline 5-95 pct). RCP
  // senaryolarının magnitüd kaymasının haritada görünmesi için TÜM senaryolar
  // bu aralığa göre boyanır. null ise frontend kendi persentilini hesaplar.
  final double? normMin;
  final double? normMax;
  final Map<String, double> scores; // il adı → yıllık ortalama değer

  const MlChoropleth({
    required this.metric,
    required this.resource,
    required this.scenario,
    required this.level,
    required this.year,
    required this.min,
    required this.max,
    required this.normMin,
    required this.normMax,
    required this.scores,
  });

  factory MlChoropleth.fromJson(Map<String, dynamic> j) {
    final raw = (j['scores'] as Map?) ?? const {};
    final scores = <String, double>{};
    raw.forEach((k, v) {
      final d = (v as num?)?.toDouble();
      if (d != null) scores[k.toString()] = d;
    });
    return MlChoropleth(
      metric: j['metric']?.toString() ?? '',
      resource: j['resource']?.toString() ?? '',
      scenario: j['scenario']?.toString() ?? 'baseline',
      level: j['level']?.toString() ?? 'province',
      year: (j['year'] as num?)?.toInt() ?? 0,
      min: (j['min'] as num?)?.toDouble(),
      max: (j['max'] as num?)?.toDouble(),
      normMin: (j['norm_min'] as num?)?.toDouble(),
      normMax: (j['norm_max'] as num?)?.toDouble(),
      scores: scores,
    );
  }
}

/// Pin finansal projeksiyon — yıllık satır.
class MlFinancialYear {
  final int year;
  final double kwh;
  final double revenueUsd;
  final double opexUsd;
  final double netUsd;
  final double cumulativeNetUsd;
  final double co2AvoidedTons;

  const MlFinancialYear({
    required this.year,
    required this.kwh,
    required this.revenueUsd,
    required this.opexUsd,
    required this.netUsd,
    required this.cumulativeNetUsd,
    required this.co2AvoidedTons,
  });

  factory MlFinancialYear.fromJson(Map<String, dynamic> j) => MlFinancialYear(
        year: (j['year'] as num?)?.toInt() ?? 0,
        kwh: (j['kwh'] as num?)?.toDouble() ?? 0,
        revenueUsd: (j['revenue_usd'] as num?)?.toDouble() ?? 0,
        opexUsd: (j['opex_usd'] as num?)?.toDouble() ?? 0,
        netUsd: (j['net_usd'] as num?)?.toDouble() ?? 0,
        cumulativeNetUsd: (j['cumulative_net_usd'] as num?)?.toDouble() ?? 0,
        co2AvoidedTons: (j['co2_avoided_tons'] as num?)?.toDouble() ?? 0,
      );
}

/// /ml/project/pin/{id}/financial yanıtı.
class MlPinFinancial {
  final int pinId;
  final String? pinName;
  final String pinType;
  final double capacityMw;
  final String method;
  final double usdToTry;
  final double priceUsdPerKwh;
  final double capexUsd;
  final double opexUsdYearly;
  final int? paybackYear;
  final double totalRevenueUsd;
  final double totalNetUsd;
  final List<MlFinancialYear> yearly;
  final String disclaimer;

  const MlPinFinancial({
    required this.pinId,
    required this.pinName,
    required this.pinType,
    required this.capacityMw,
    required this.method,
    required this.usdToTry,
    required this.priceUsdPerKwh,
    required this.capexUsd,
    required this.opexUsdYearly,
    required this.paybackYear,
    required this.totalRevenueUsd,
    required this.totalNetUsd,
    required this.yearly,
    required this.disclaimer,
  });

  factory MlPinFinancial.fromJson(Map<String, dynamic> j) {
    final yr = ((j['yearly'] as List?) ?? const [])
        .map((e) => MlFinancialYear.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return MlPinFinancial(
      pinId: (j['pin_id'] as num?)?.toInt() ?? 0,
      pinName: j['pin_name']?.toString(),
      pinType: j['pin_type']?.toString() ?? '',
      capacityMw: (j['capacity_mw'] as num?)?.toDouble() ?? 0,
      method: j['method']?.toString() ?? '',
      usdToTry: (j['usd_to_try'] as num?)?.toDouble() ?? 33.0,
      priceUsdPerKwh: (j['price_usd_per_kwh'] as num?)?.toDouble() ?? 0,
      capexUsd: (j['capex_usd'] as num?)?.toDouble() ?? 0,
      opexUsdYearly: (j['opex_usd_yearly'] as num?)?.toDouble() ?? 0,
      paybackYear: (j['payback_year'] as num?)?.toInt(),
      totalRevenueUsd: (j['total_revenue_usd'] as num?)?.toDouble() ?? 0,
      totalNetUsd: (j['total_net_usd'] as num?)?.toDouble() ?? 0,
      yearly: yr,
      disclaimer: j['disclaimer']?.toString() ?? '',
    );
  }
}

/// M-H.1: Birleşik historical + forecast seri.
class MlSeriesPoint {
  final DateTime date;
  final double value;
  final double? lower;
  final double? upper;
  const MlSeriesPoint({
    required this.date,
    required this.value,
    this.lower,
    this.upper,
  });
  factory MlSeriesPoint.fromJson(Map<String, dynamic> j) => MlSeriesPoint(
        date: DateTime.parse(j['date'] as String),
        value: (j['value'] as num).toDouble(),
        lower: (j['lower'] as num?)?.toDouble(),
        upper: (j['upper'] as num?)?.toDouble(),
      );
}

class MlSeries {
  final String province;
  final String? district;
  final String metric;
  final String scenario;
  final List<MlSeriesPoint> historical;
  final List<MlSeriesPoint> forecast;
  const MlSeries({
    required this.province,
    required this.district,
    required this.metric,
    required this.scenario,
    required this.historical,
    required this.forecast,
  });
  factory MlSeries.fromJson(Map<String, dynamic> j) => MlSeries(
        province: j['province']?.toString() ?? '',
        district: j['district']?.toString(),
        metric: j['metric']?.toString() ?? '',
        scenario: j['scenario']?.toString() ?? 'baseline',
        historical: ((j['historical'] as List?) ?? const [])
            .map((e) => MlSeriesPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        forecast: ((j['forecast'] as List?) ?? const [])
            .map((e) => MlSeriesPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// /ml/health yanıtı — dependency durum kontrolü.
class MlHealth {
  final bool ready;
  final bool autoArima;
  final Map<String, String> dependencies;

  const MlHealth({
    required this.ready,
    required this.autoArima,
    required this.dependencies,
  });

  factory MlHealth.fromJson(Map<String, dynamic> j) {
    final deps = <String, String>{};
    final raw = (j['dependencies'] as Map?) ?? const {};
    raw.forEach((k, v) => deps[k.toString()] = v.toString());
    return MlHealth(
      ready: j['ready'] == true,
      autoArima: j['auto_arima'] == true,
      dependencies: deps,
    );
  }
}

class MlForecastService extends BaseService {
  MlForecastService(super.storageService);

  /// Pin için SARIMAX forecast.
  /// [years]: 1-10
  Future<MlForecastResponse> forecastPin({
    required int pinId,
    int years = 5,
  }) async {
    final uri = Uri.parse('$baseUrl/ml/project/pin/$pinId').replace(
      queryParameters: {'years': '$years'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /ml/project/pin/$pinId');
    }
    return MlForecastResponse.fromJson(Map<String, dynamic>.from(data));
  }

  /// İl climatology forecast.
  /// [resource]: solar | wind | hydro
  /// [metric]: sunshine | precipitation | cloud | discharge
  Future<MlForecastResponse> forecastProvince({
    required String province,
    int years = 5,
    String resource = 'solar',
    String metric = 'sunshine',
  }) async {
    final uri = Uri.parse('$baseUrl/ml/project/province/$province').replace(
      queryParameters: {
        'years': '$years',
        'resource': resource,
        'metric': metric,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /ml/project/province/$province');
    }
    return MlForecastResponse.fromJson(Map<String, dynamic>.from(data));
  }

  /// İklim senaryosu projeksiyonu — baseline + RCP4.5 + RCP8.5.
  Future<MlScenarioResponse> scenarioProvince({
    required String province,
    int years = 10,
    String resource = 'solar',
    String metric = 'sunshine',
  }) async {
    final uri = Uri.parse('$baseUrl/ml/scenario/province/$province').replace(
      queryParameters: {
        'years': '$years',
        'resource': resource,
        'metric': metric,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /ml/scenario/province/$province');
    }
    return MlScenarioResponse.fromJson(Map<String, dynamic>.from(data));
  }

  /// Tematik harita: belirli yıl+senaryo için {il → değer}.
  /// M-B.1 — ml_forecast precompute tablosundan.
  Future<MlChoropleth> mlChoropleth({
    required String metric,
    required int year,
    int? month, // M-H.4: opsiyonel ay (1-12); null = yıllık ortalama
    String resource = 'solar',
    String scenario = 'baseline',
    String level = 'province',
  }) async {
    final params = <String, String>{
      'year': '$year',
      'resource': resource,
      'scenario': scenario,
      'level': level,
    };
    if (month != null) params['month'] = '$month';
    final uri = Uri.parse('$baseUrl/ml/choropleth/$metric').replace(
      queryParameters: params,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /ml/choropleth/$metric');
    }
    return MlChoropleth.fromJson(Map<String, dynamic>.from(data));
  }

  /// Mevcut forecast yıl aralığı (slider min/max).
  Future<(int, int)> mlChoroplethYears({
    required String metric,
    String resource = 'solar',
  }) async {
    final uri = Uri.parse('$baseUrl/ml/choropleth/$metric/years').replace(
      queryParameters: {'resource': resource},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: years');
    }
    final mn = (data['min_year'] as num?)?.toInt() ?? DateTime.now().year;
    final mx = (data['max_year'] as num?)?.toInt() ?? (mn + 10);
    return (mn, mx);
  }

  /// Pin finansal projeksiyon (M-C) — yıllık gelir/gider/net + payback.
  Future<MlPinFinancial> pinFinancial({
    required int pinId,
    int years = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/ml/project/pin/$pinId/financial').replace(
      queryParameters: {'years': '$years'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: pin financial');
    }
    return MlPinFinancial.fromJson(Map<String, dynamic>.from(data));
  }

  /// M-H.1: Birleşik aylık seri (10y geçmiş + 10y projeksiyon).
  /// Reports/Projeksiyon "tüm yıllar" grafiği için.
  Future<MlSeries> mlSeries({
    required String province,
    String? district,
    String metric = 'sunshine',
    int historyYears = 10,
    int horizonYears = 10,
    String scenario = 'baseline',
  }) async {
    final params = <String, String>{
      'metric': metric,
      'history_years': '$historyYears',
      'horizon_years': '$horizonYears',
      'scenario': scenario,
    };
    if (district != null) params['district'] = district;
    final uri = Uri.parse('$baseUrl/ml/series/$province').replace(
      queryParameters: params,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    final data = processResponse(response);
    if (data is! Map) throw Exception('Beklenmeyen yanıt: ml/series');
    return MlSeries.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MlHealth> health() async {
    final uri = Uri.parse('$baseUrl/ml/health');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /ml/health');
    }
    return MlHealth.fromJson(Map<String, dynamic>.from(data));
  }
}
