import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/network/api_client.dart';

class ResourceService extends BaseService {
  ResourceService(super.storageService);

  Future<List<Pin>> fetchPins() async {
    final response = await http.get(
      Uri.parse('$baseUrl/pins/'),
      headers: await getHeaders(),
    );
    final data = processResponse(response);
    if (data is List) {
      return data.map((json) => Pin.fromJson(json)).toList();
    }
     throw Exception('Kaynaklar yüklenemedi: $data');
  }

  Future<Pin> addPin(
    LatLng point,
    String name,
    String type,
    double capacityMw,
    int? equipmentId,
    double? panelArea, {
    double? flowRate,
    double? headHeight,
    double? basinAreaKm2,
    String? city,
    String? district,
    String? waterBodyName,
    // 2026-05-17 Sprint A — Gelişmiş Ayarlar manuel parametreler
    double? panelTilt,
    double? panelAzimuth,
    double? panelPowerW,
    double? hubHeight,
    double? rotorDiameter,
    double? ratedPowerKw,
  }) async {
    final Map<String, dynamic> pinData = {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'title': name,   // backend schema: PinBase.title
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (flowRate != null) 'flow_rate': flowRate,
      if (headHeight != null) 'head_height': headHeight,
      if (basinAreaKm2 != null) 'basin_area_km2': basinAreaKm2,
      if (city != null && city.isNotEmpty) 'city': city,
      if (district != null && district.isNotEmpty) 'district': district,
      if (waterBodyName != null && waterBodyName.isNotEmpty) 'water_body_name': waterBodyName,
      if (panelTilt != null) 'panel_tilt': panelTilt,
      if (panelAzimuth != null) 'panel_azimuth': panelAzimuth,
      if (panelPowerW != null) 'panel_power_w': panelPowerW,
      if (hubHeight != null) 'hub_height': hubHeight,
      if (rotorDiameter != null) 'rotor_diameter': rotorDiameter,
      if (ratedPowerKw != null) 'rated_power_kw': ratedPowerKw,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/pins/'),
      headers: await getHeaders(),
      body: json.encode(pinData),
    );

    if (response.statusCode == 201) {
       final data = processResponse(response);
       return Pin.fromJson(data);
    }
    throw Exception('Pin eklenemedi (Status code: ${response.statusCode})');
  }

  Future<Pin> updatePin(
    int pinId,
    LatLng point,
    String name,
    String type,
    double capacityMw,
    int? equipmentId,
    double? panelArea, {
    double? flowRate,
    double? headHeight,
    double? basinAreaKm2,
    String? city,
    String? district,
    String? waterBodyName,
    double? panelTilt,
    double? panelAzimuth,
    double? panelPowerW,
    double? hubHeight,
    double? rotorDiameter,
    double? ratedPowerKw,
  }) async {
    final Map<String, dynamic> pinData = {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'title': name,
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (flowRate != null) 'flow_rate': flowRate,
      if (headHeight != null) 'head_height': headHeight,
      if (basinAreaKm2 != null) 'basin_area_km2': basinAreaKm2,
      if (city != null && city.isNotEmpty) 'city': city,
      if (district != null && district.isNotEmpty) 'district': district,
      if (waterBodyName != null && waterBodyName.isNotEmpty) 'water_body_name': waterBodyName,
      if (panelTilt != null) 'panel_tilt': panelTilt,
      if (panelAzimuth != null) 'panel_azimuth': panelAzimuth,
      if (panelPowerW != null) 'panel_power_w': panelPowerW,
      if (hubHeight != null) 'hub_height': hubHeight,
      if (rotorDiameter != null) 'rotor_diameter': rotorDiameter,
      if (ratedPowerKw != null) 'rated_power_kw': ratedPowerKw,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/pins/$pinId'),
      headers: await getHeaders(),
      body: json.encode(pinData),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return Pin.fromJson(data);
    }
    throw Exception('Pin güncellenemedi (Status code: ${response.statusCode})');
  }

  Future<void> deletePin(int pinId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/pins/$pinId'),
      headers: await getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Pin silinemedi (Status code: ${response.statusCode})');
    }
  }

  Future<PinCalculationResponse> calculateEnergyPotential({
    required double lat,
    required double lon,
    required String type,
    required double capacityMw,
    required double panelArea,
    double? flowRate,
    double? headHeight,
    double? basinAreaKm2,
  }) async {
    final Map<String, dynamic> pinData = {
      'latitude': lat,
      'longitude': lon,
      'title': "Hesaplanacak",
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
      if (flowRate != null) 'flow_rate': flowRate,
      if (headHeight != null) 'head_height': headHeight,
      if (basinAreaKm2 != null) 'basin_area_km2': basinAreaKm2,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/pins/calculate'),
      headers: await getHeaders(),
      body: json.encode(pinData),
    );

   if (response.statusCode == 200) {
      final data = processResponse(response);
      return PinCalculationResponse.fromJson(data);
    }
    throw Exception(
      'Hesaplama başarısız (Status code: ${response.statusCode})',
    );
  }
  Future<Pin> analyzePin(int pinId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pins/$pinId/analyze'),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return Pin.fromJson(data);
    }
    throw Exception('Analiz başarısız (Status code: ${response.statusCode})');
  }

  /// İki nokta (Su Alma + Türbin) arasında rakım farkı, mesafe ve cebri boru maliyeti hesaplar
  Future<Map<String, dynamic>> hydroElevationAnalysis({
    required double intakeLat,
    required double intakeLon,
    required double turbineLat,
    required double turbineLon,
    double? flowRate,
  }) async {
    final Map<String, dynamic> body = {
      'intake_lat': intakeLat,
      'intake_lon': intakeLon,
      'turbine_lat': turbineLat,
      'turbine_lon': turbineLon,
      if (flowRate != null) 'flow_rate': flowRate,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/pins/hydro/elevation'),
      headers: await getHeaders(),
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return processResponse(response) as Map<String, dynamic>;
    }
    throw Exception('Rakım analizi başarısız (Status code: ${response.statusCode})');
  }

  /// Tüm pinleri güncel saatlik verilerle toplu yeniden analiz eder
  Future<Map<String, dynamic>> batchReanalyze() async {
    final response = await http.post(
      Uri.parse('$baseUrl/pins/batch/reanalyze'),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      return processResponse(response) as Map<String, dynamic>;
    }
    throw Exception('Toplu analiz başarısız (Status code: ${response.statusCode})');
  }

  /// GET /pins/{id}/generation — Pin'in dönem bazlı üretim geçmişi.
  ///
  /// [period]: today | week | month | year | total
  Future<PinGeneration> fetchPinGeneration(
    int pinId, {
    String period = 'month',
  }) async {
    final uri = Uri.parse('$baseUrl/pins/$pinId/generation')
        .replace(queryParameters: {'period': period});
    final response = await http.get(uri, headers: await getHeaders());
    final data = processResponse(response);
    if (data is! Map) {
      throw Exception('Beklenmeyen yanıt: /pins/$pinId/generation');
    }
    return PinGeneration.fromJson(Map<String, dynamic>.from(data));
  }
}

/// /pins/{id}/generation yanıtı.
class PinGeneration {
  final int pinId;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final double totalKwh;
  final List<GenerationPoint> dailyBreakdown;
  final double? comparisonPrevPeriodKwh;
  final double? comparisonPctChange;
  final String dataSource; // hourly_actual | climatology_interpolated | hybrid

  const PinGeneration({
    required this.pinId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalKwh,
    required this.dailyBreakdown,
    required this.comparisonPrevPeriodKwh,
    required this.comparisonPctChange,
    required this.dataSource,
  });

  factory PinGeneration.fromJson(Map<String, dynamic> j) {
    return PinGeneration(
      pinId: (j['pin_id'] as num?)?.toInt() ?? 0,
      period: j['period']?.toString() ?? '',
      startDate: DateTime.tryParse(j['start_date']?.toString() ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(j['end_date']?.toString() ?? '') ??
          DateTime.now(),
      totalKwh: (j['total_kwh'] as num?)?.toDouble() ?? 0,
      dailyBreakdown: ((j['daily_breakdown'] as List?) ?? const [])
          .map((e) => GenerationPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      comparisonPrevPeriodKwh:
          (j['comparison_prev_period_kwh'] as num?)?.toDouble(),
      comparisonPctChange: (j['comparison_pct_change'] as num?)?.toDouble(),
      dataSource: j['data_source']?.toString() ?? 'unknown',
    );
  }
}

class GenerationPoint {
  final String date;
  final double kwh;
  const GenerationPoint({required this.date, required this.kwh});
  factory GenerationPoint.fromJson(Map<String, dynamic> j) => GenerationPoint(
        date: j['date']?.toString() ?? '',
        kwh: (j['kwh'] as num?)?.toDouble() ?? 0,
      );
}
