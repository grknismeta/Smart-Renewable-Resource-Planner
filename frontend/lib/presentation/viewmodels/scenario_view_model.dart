import 'package:flutter/foundation.dart';
import '../../core/api_service.dart';
import '../../data/models/scenario_model.dart';
import '../../core/base/base_view_model.dart';

class ScenarioViewModel extends BaseViewModel {
  final ApiService _apiService;

  ScenarioViewModel(this._apiService);

  List<Scenario> _scenarios = [];
  Scenario? _selectedScenario;

  List<Scenario> get scenarios => _scenarios;
  Scenario? get selectedScenario => _selectedScenario;

  Future<void> loadScenarios() async {
    setBusy(true);

    try {
      _scenarios = await _apiService.fetchScenarios();
    } catch (e) {
      debugPrint('Senaryolar yüklenemedi: $e');
      _scenarios = [];
      setError('Senaryolar yüklenemedi');
    } finally {
      setBusy(false);
    }
  }

  Future<void> createScenario(ScenarioCreate scenarioCreate) async {
    setBusy(true);

    try {
      final newScenario = await _apiService.createScenario(scenarioCreate);
      _scenarios.insert(0, newScenario);
    } catch (e) {
      debugPrint('Senaryo oluşturulamadı: $e');
      setError('Senaryo oluşturulamadı');
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> calculateScenario(int scenarioId) async {
    setBusy(true);

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
      setError('Senaryo hesaplanamadı');
      rethrow;
    } finally {
      setBusy(false);
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
