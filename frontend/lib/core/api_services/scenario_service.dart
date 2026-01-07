import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/scenario_model.dart';
import 'base_service.dart';

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
    throw Exception('Senaryo oluşturulamadı (status: ${response.statusCode})');
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
    throw Exception('Senaryo güncellenemedi (status: ${response.statusCode})');
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
    throw Exception('Senaryo hesaplanamadı (status: ${response.statusCode})');
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
}
