import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/system_data_models.dart';
import 'base_service.dart';

class EquipmentService extends BaseService {
  EquipmentService(super.storageService);

  Future<List<Equipment>> fetchEquipments({String? type}) async {
    debugPrint('[EquipmentService.fetchEquipments] Çağrıldı: type=$type');
    final query = type != null ? '?type=$type' : '';
    debugPrint(
      '[EquipmentService.fetchEquipments] URL: $baseUrl/equipments$query',
    );
    final response = await http.get(
      Uri.parse('$baseUrl/equipments$query'),
      headers: await getHeaders(),
    );

    debugPrint(
      '[EquipmentService.fetchEquipments] Response status: ${response.statusCode}',
    );
    
    final data = processResponse(response);
    if (data is List) {
       debugPrint('[EquipmentService.fetchEquipments] ${data.length} ekipman alındı');
       return data.map((e) => Equipment.fromJson(e)).toList();
    }
    throw Exception('Ekipman listesi formatı hatalı: $data');
  }
}
