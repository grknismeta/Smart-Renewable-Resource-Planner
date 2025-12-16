import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../data/models/scenario_model.dart';

class ScenarioProvider extends ChangeNotifier {
  final ApiService _apiService;

  ScenarioProvider(this._apiService);

  bool _isLoading = false;
  List<Scenario> _scenarios = [];
  Scenario? _selectedScenario;

  bool get isLoading => _isLoading;
  List<Scenario> get scenarios => _scenarios;
  Scenario? get selectedScenario => _selectedScenario;

  Future<void> loadScenarios() async {
    _isLoading = true;
    notifyListeners();

    try {
      _scenarios = await _apiService.fetchScenarios();
    } catch (e) {
      print('Senaryolar yüklenemedi: $e');
      _scenarios = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createScenario(ScenarioCreate scenarioCreate) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newScenario = await _apiService.createScenario(scenarioCreate);
      _scenarios.insert(0, newScenario);
    } catch (e) {
      print('Senaryo oluşturulamadı: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectScenario(Scenario scenario) {
    _selectedScenario = scenario;
    notifyListeners();
  }

  void clearSelection() {
    _selectedScenario = null;
    notifyListeners();
  }
}
