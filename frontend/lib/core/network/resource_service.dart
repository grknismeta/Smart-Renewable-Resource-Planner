import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/network/api_client.dart';

class ResourceService extends BaseService {
  ResourceService(super.storageService);

  Future<List<Pin>> fetchPins() async {
    debugPrint(
      '[ResourceService.fetchPins] API çağrısı yapılıyor: $baseUrl/pins/',
    );
    final response = await http.get(
      Uri.parse('$baseUrl/pins/'),
      headers: await getHeaders(),
    );
    debugPrint(
      '[ResourceService.fetchPins] Response status: ${response.statusCode}',
    );
    
    final data = processResponse(response);
    if (data is List) {
      debugPrint(
        '[ResourceService.fetchPins] ${data.length} pin JSON den parse edildi',
      );
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
}
