import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('Senaryolar yüklenemedi: $e');
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
      debugPrint('Senaryo oluşturulamadı: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> calculateScenario(int scenarioId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedScenario = await _apiService.calculateScenario(scenarioId);
      final index = _scenarios.indexWhere((s) => s.id == scenarioId);
      if (index != -1) {
        _scenarios[index] = updatedScenario;
        if (_selectedScenario?.id == scenarioId) {
          _selectedScenario = updatedScenario;
        }
      }
    } catch (e) {
      debugPrint('Senaryo hesaplanamadı: $e');
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
