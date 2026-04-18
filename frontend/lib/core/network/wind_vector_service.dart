import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class WindVectorService extends BaseService {
  WindVectorService(super.storageService);

  Future<List<Map<String, dynamic>>> fetchWindVectors({bool dense = true}) async {
    final uri = Uri.parse('$baseUrl/wind-vectors?dense=$dense');
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Rüzgar vektör verisi alınamadı');
  }
}
