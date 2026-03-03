import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class GeoService extends BaseService {
  GeoService(super.storageService);

  Future<Map<String, dynamic>> checkGeoSuitability(
    double lat,
    double lon,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/geo/check-suitability'),
      headers: await getHeaders(),
      body: json.encode({'latitude': lat, 'longitude': lon}),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return data as Map<String, dynamic>;
    } else {
      throw Exception('Coğrafi analiz yapılamadı: ${response.statusCode}');
    }
  }
}
