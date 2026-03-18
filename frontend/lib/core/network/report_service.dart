import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/core/network/api_client.dart';

class ReportService extends BaseService {
  ReportService(super.storageService);

  Future<RegionalReport> fetchRegionalReport({
    required String region,
    required String type,
    String interval = 'Yıllık',
    int limit = 400,
    String? province,
  }) async {
    final params = <String, String>{
      'region': region,
      'type': type,
      'interval': interval,
      'limit': '$limit',
    };
    if (province != null && province.isNotEmpty) {
      params['province'] = province;
    }
    final uri = Uri.parse('$baseUrl/reports/regional').replace(queryParameters: params);

    final response = await http.get(uri, headers: await getHeaders());
    final data = processResponse(response);
    if (data != null) {
        return RegionalReport.fromJson(data);
    }
    throw Exception('Rapor verisi alınamadı');
  }

  Future<List<Map<String, dynamic>>> fetchInterpolatedMap(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/interpolated-map?type=$type&resolution=0.1'),
        headers: await getHeaders(),
      );
      
      final data = processResponse(response);
      if (data is List) {
         return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Interpolated map format failed');
    } catch (e) {
      debugPrint('Interpolated Map Error: $e');
      return []; 
    }
  }
}
