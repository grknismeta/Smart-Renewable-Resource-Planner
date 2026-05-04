import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/data/models/financial_metrics.dart';
import 'package:frontend/core/network/api_client.dart';

class ScenarioService extends BaseService {
  ScenarioService(super.storageService);

  Future<List<Scenario>> fetchScenarios() async {
    final response = await http.get(
      Uri.parse('$baseUrl/scenarios/'),
      headers: await getHeaders(),
    );

    final data = processResponse(response);
    if (data is List) {
       return data.map((e) => Scenario.fromJson(e)).toList();
    }
    throw Exception('Senaryolar yüklenemedi: $data');
  }

  Future<Scenario> createScenario(ScenarioCreate scenario) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scenarios/'),
      headers: await getHeaders(),
      body: json.encode(scenario.toJson()),
    );

    if (response.statusCode == 201) {
      final data = processResponse(response);
      return Scenario.fromJson(data);
    }
    String detail = '';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] is String) {
        detail = body['detail'] as String;
      }
    } catch (_) {}
    throw Exception(
      detail.isNotEmpty
          ? detail
          : 'Senaryo oluşturulamadı (status: ${response.statusCode})',
    );
  }

  Future<Scenario> updateScenario(
    int scenarioId,
    ScenarioCreate scenario,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/scenarios/$scenarioId'),
      headers: await getHeaders(),
      body: json.encode(scenario.toJson()),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return Scenario.fromJson(data);
    }
    // Sunucunun döndüğü 'detail' mesajını kullanıcıya ilet
    // (404 "Senaryo bulunamadı", 403 "Pin X'e erişim yetkiniz yok" vb.).
    String detail = '';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] is String) {
        detail = body['detail'] as String;
      }
    } catch (_) {}
    throw Exception(
      detail.isNotEmpty
          ? detail
          : 'Senaryo güncellenemedi (status: ${response.statusCode})',
    );
  }

  Future<Scenario> calculateScenario(int scenarioId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scenarios/$scenarioId/calculate'),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return Scenario.fromJson(data);
    }
    // Sunucunun döndüğü 'detail' mesajını kullanıcıya ilet (400/404'te
    // "Tarih aralığı eksik" / "Pin yok" gibi tanılamaya yardımcı olur).
    String detail = '';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] is String) {
        detail = body['detail'] as String;
      }
    } catch (_) {}
    throw Exception(
      detail.isNotEmpty
          ? detail
          : 'Senaryo hesaplanamadı (status: ${response.statusCode})',
    );
  }

  Future<Scenario> addPinsToScenario(int scenarioId, List<int> pinIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scenarios/$scenarioId/pins'),
      headers: await getHeaders(),
      body: json.encode(pinIds),
    );

    if (response.statusCode == 200) {
      final data = processResponse(response);
      return Scenario.fromJson(data);
    }
    throw Exception(
      'Senaryoya pin eklenemedi (status: ${response.statusCode})',
    );
  }

  /// Senaryonun finansal projeksiyon metriklerini getirir (Aşama 3.A).
  ///
  /// Backend ``GET /scenarios/{id}/financials`` çağrısı:
  /// CAPEX, OPEX, LCOE, Payback, NPV, IRR, yıllık üretim, CO₂ avoidance
  /// ve 25 yıllık kümülatif nakit akışı.
  Future<FinancialMetrics> fetchScenarioFinancials(int scenarioId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/scenarios/$scenarioId/financials'),
      headers: await getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = processResponse(response);
      if (data is Map<String, dynamic>) {
        return FinancialMetrics.fromJson(data);
      }
    }
    String detail = '';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] is String) {
        detail = body['detail'] as String;
      }
    } catch (_) {}
    throw Exception(
      detail.isNotEmpty
          ? detail
          : 'Finansal projeksiyon alınamadı (status: ${response.statusCode})',
    );
  }
}
