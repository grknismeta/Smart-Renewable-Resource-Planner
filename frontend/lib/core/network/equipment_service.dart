import 'dart:convert';
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

  /// 2026-05-17 Sprint A — Kullanıcının kendi ekipmanını kaydeder.
  /// 'Panel Tipini Kaydet' / 'Türbin Tipini Kaydet' butonu için.
  /// Backend owner_id=current_user.id ile insert eder.
  Future<Equipment> createEquipment({
    required String name,
    required String type, // 'Solar' / 'Wind' / 'Hydro'
    required double ratedPowerKw,
    double? efficiency,
    double? costPerUnit,
    Map<String, dynamic>? specs,
  }) async {
    final body = {
      'name': name,
      'type': type,
      'rated_power_kw': ratedPowerKw,
      if (efficiency != null) 'efficiency': efficiency,
      if (costPerUnit != null) 'cost_per_unit': costPerUnit,
      if (specs != null) 'specs': specs,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/equipments/'),
      headers: await getHeaders(),
      body: json.encode(body),
    );
    final data = processResponse(response);
    return Equipment.fromJson(data);
  }

  /// Kullanıcının kendi ekipmanını günceller (sistem ekipmanları → 404).
  /// 2026-05-17 — 'Eklediğimiz panel tiplerini sonradan değiştirebiliyor
  /// olmalıyız' isteği.
  Future<Equipment> updateEquipment({
    required int equipmentId,
    required String name,
    required String type,
    required double ratedPowerKw,
    double? efficiency,
    double? costPerUnit,
    Map<String, dynamic>? specs,
  }) async {
    final body = {
      'name': name,
      'type': type,
      'rated_power_kw': ratedPowerKw,
      if (efficiency != null) 'efficiency': efficiency,
      if (costPerUnit != null) 'cost_per_unit': costPerUnit,
      if (specs != null) 'specs': specs,
    };
    final response = await http.put(
      Uri.parse('$baseUrl/equipments/$equipmentId'),
      headers: await getHeaders(),
      body: json.encode(body),
    );
    final data = processResponse(response);
    return Equipment.fromJson(data);
  }

  /// Kullanıcının kendi ekipmanını siler (sistem ekipmanları silinemez → 404).
  Future<bool> deleteEquipment(int equipmentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/equipments/$equipmentId'),
      headers: await getHeaders(),
    );
    return response.statusCode == 204 || response.statusCode == 200;
  }
}
