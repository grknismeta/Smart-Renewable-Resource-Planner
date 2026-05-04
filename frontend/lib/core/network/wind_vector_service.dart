import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class WindVectorService extends BaseService {
  WindVectorService(super.storageService);

  /// Rüzgar vektörlerini getirir.
  ///
  /// [mode]: 'current' (varsayılan) | 'yearly' | 'season'
  /// [season]: mode='season' iken zorunlu (winter|spring|summer|autumn)
  Future<List<Map<String, dynamic>>> fetchWindVectors({
    bool dense = true,
    String mode = 'current',
    String? season,
  }) async {
    final params = <String, String>{
      'dense': '$dense',
      'mode': mode,
    };
    if (season != null) params['season'] = season;
    final uri = Uri.parse('$baseUrl/wind-vectors').replace(queryParameters: params);
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Rüzgar vektör verisi alınamadı');
  }
}
