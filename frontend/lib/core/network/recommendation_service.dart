import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/models/recommendation_model.dart';

class RecommendationService extends BaseService {
  RecommendationService(super.storageService);

  Future<RecommendationsData> fetchRecommendations({
    int hours = 168,
    int topN = 8,
  }) async {
    final uri = Uri.parse('$baseUrl/recommendations').replace(
      queryParameters: {
        'hours': '$hours',
        'top_n': '$topN',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final data = processResponse(response);
    if (data is Map) {
      return RecommendationsData.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Öneri verisi alınamadı');
  }
}
