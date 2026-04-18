import 'package:http/http.dart' as http;
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/core/network/api_client.dart';

class EquipmentService extends BaseService {
  EquipmentService(super.storageService);

  Future<List<Equipment>> fetchEquipments({String? type}) async {
    final query = type != null ? '?type=$type' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/equipments$query'),
      headers: await getHeaders(),
    );

    final data = processResponse(response);
    if (data is List) {
       return data.map((e) => Equipment.fromJson(e)).toList();
    }
    throw Exception('Ekipman listesi formatı hatalı: $data');
  }
}
