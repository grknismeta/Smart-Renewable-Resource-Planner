import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class GeoService extends BaseService {
  GeoService(super.storageService);

  /// Koordinata göre il/ilçe adı döndürür. Hata durumunda boş map döner.
  Future<Map<String, String>> getCityForCoords(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/geo/city?lat=$lat&lon=$lon'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = processResponse(response) as Map<String, dynamic>;
        // "Bilinmiyor" eski DB kayıtları için de boş döndür
        String prov = data['province']?.toString() ?? '';
        String dist = data['district']?.toString() ?? '';
        if (prov == 'Bilinmiyor') prov = '';
        if (dist == 'Bilinmiyor') dist = '';
        return {'province': prov, 'district': dist};
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> checkGeoSuitability(
    double lat,
    double lon,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/geo/check-suitability'),
        headers: await getHeaders(),
        body: json.encode({'latitude': lat, 'longitude': lon}),
      );

      if (response.statusCode == 200) {
        final data = processResponse(response);
        return data as Map<String, dynamic>;
      }

      // Geo motoru kapalı (404) veya erişilemiyor → her konum serbest
      return {'suitable': true, 'geo_disabled': true};
    } catch (e) {
      // Ağ hatası, timeout vs. → engellemeden devam et
      debugPrint('[GeoService] Hata yakalandı, geo atlanıyor: $e');
      return {'suitable': true, 'geo_disabled': true};
    }
  }
}
