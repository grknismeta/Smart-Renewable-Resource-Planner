import 'package:http/http.dart' as http;
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/core/network/api_client.dart';

class ReportService extends BaseService {
  ReportService(super.storageService);

  Future<RegionalReport> fetchRegionalReport({
    required String region,
    required String type,
    String interval = 'Yıllık',
    int limit = 1000,
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

  // 1.A2: fetchInterpolatedMap (IDW heatmap noktaları) emekliye ayrıldı —
  // tek görsel dil ilçe choropleth (`WeatherService.fetchDistrictChoropleth`).
  // Backend `/reports/interpolated-map` endpoint'i de aynı turda silindi.
}
