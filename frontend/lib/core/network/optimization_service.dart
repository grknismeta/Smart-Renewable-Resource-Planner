import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/core/network/api_client.dart';

class OptimizationService extends BaseService {
  OptimizationService(super.storageService);

  Future<OptimizationResponse> optimizeWindPlacement({
    required double topLeftLat,
    required double topLeftLon,
    required double bottomRightLat,
    required double bottomRightLon,
    required int equipmentId,
    double minDistanceM = 0.0,
  }) async {
    final Map<String, dynamic> requestData = {
      'top_left_lat': topLeftLat,
      'top_left_lon': topLeftLon,
      'bottom_right_lat': bottomRightLat,
      'bottom_right_lon': bottomRightLon,
      'equipment_id': equipmentId,
      'min_distance_m': minDistanceM,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/optimization/wind-placement'),
      headers: await getHeaders(),
      body: json.encode(requestData),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return OptimizationResponse.fromJson(data);
    } 
    throw Exception(
        'Optimizasyon hesaplaması başarısız (Status code: ${response.statusCode})',
      );
  }
}
