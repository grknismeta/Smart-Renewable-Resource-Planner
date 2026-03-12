import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/core/base/base_view_model.dart';

class ScenarioViewModel extends BaseViewModel {
  final ApiService _apiService;

  ScenarioViewModel(this._apiService);

  List<Scenario> _scenarios = [];
  Scenario? _selectedScenario;

  // Multi-select support
  final Set<int> _selectedScenarioIds = {};

  List<Scenario> get scenarios => _scenarios;
  Scenario? get selectedScenario => _selectedScenario;
  Set<int> get selectedScenarioIds => _selectedScenarioIds;
  bool get hasSelection => _selectedScenarioIds.isNotEmpty;
  bool isSelected(int id) => _selectedScenarioIds.contains(id);

  /// Pin IDs from all currently selected scenarios
  Set<int> get selectedPinIds {
    if (_selectedScenarioIds.isEmpty) return {};
    final result = <int>{};
    for (final s in _scenarios) {
      if (_selectedScenarioIds.contains(s.id)) {
        result.addAll(s.pinIds);
      }
    }
    return result;
  }

  void toggleScenario(int id) {
    if (_selectedScenarioIds.contains(id)) {
      _selectedScenarioIds.remove(id);
    } else {
      _selectedScenarioIds.add(id);
    }
    notifyListeners();
  }

  void clearAllSelections() {
    _selectedScenarioIds.clear();
    notifyListeners();
  }

  Future<void> loadScenarios() async {
    setBusy(true);

    try {
      _scenarios = await _apiService.scenario.fetchScenarios();
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
      final newScenario = await _apiService.scenario.createScenario(scenarioCreate);
      _scenarios.insert(0, newScenario);
    } catch (e) {
      debugPrint('Senaryo oluşturulamadı: $e');
      setError('Senaryo oluşturulamadı');
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> updateScenario(
    int scenarioId,
    ScenarioCreate scenarioCreate,
  ) async {
    setBusy(true);

    try {
      final updatedScenario = await _apiService.scenario.updateScenario(
        scenarioId,
        scenarioCreate,
      );
      final index = _scenarios.indexWhere((s) => s.id == scenarioId);
      if (index != -1) {
        _scenarios[index] = updatedScenario;
        if (_selectedScenario?.id == scenarioId) {
          _selectedScenario = updatedScenario;
        }
        notifyListeners(); // Liste güncellendi
      }
    } catch (e) {
      debugPrint('Senaryo güncellenemedi: $e');
      setError('Senaryo güncellenemedi');
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> calculateScenario(int scenarioId) async {
    setBusy(true);

    try {
      final updatedScenario = await _apiService.scenario.calculateScenario(scenarioId);
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
