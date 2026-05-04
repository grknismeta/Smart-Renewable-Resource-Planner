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

  // Aşama 2: Senaryo haritada göster/gizle — varsayılan olarak tüm senaryolar
  // görünür (set boş). Kullanıcı göz ikonuna basınca id eklenir; map widget'ları
  // `hiddenPinIds`'i okuyup pin listesinden filtreler.
  final Set<int> _hiddenScenarioIds = {};

  List<Scenario> get scenarios => _scenarios;
  Scenario? get selectedScenario => _selectedScenario;
  Set<int> get selectedScenarioIds => _selectedScenarioIds;
  bool get hasSelection => _selectedScenarioIds.isNotEmpty;
  bool isSelected(int id) => _selectedScenarioIds.contains(id);
  bool isVisible(int id) => !_hiddenScenarioIds.contains(id);

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

  /// Gizli senaryoların birleşik pin ID'leri — map widget'larında pin
  /// listesinden filtrelemek için tüketilir.
  Set<int> get hiddenPinIds {
    if (_hiddenScenarioIds.isEmpty) return const {};
    final result = <int>{};
    for (final s in _scenarios) {
      if (_hiddenScenarioIds.contains(s.id)) {
        result.addAll(s.pinIds);
      }
    }
    return result;
  }

  /// Senaryoyu haritada göster/gizle — pin'ler filtrelenir, mini-report
  /// seçimi ile karışmaz (toggleScenario `_selectedScenarioIds`'i yönetir).
  void toggleScenarioVisibility(int id) {
    if (_hiddenScenarioIds.contains(id)) {
      _hiddenScenarioIds.remove(id);
    } else {
      _hiddenScenarioIds.add(id);
    }
    notifyListeners();
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

  /// Mevcut seçimi temizleyip verilen id'yi tekil olarak seçer.
  /// Raporlar sayfası `scenarioId` argümanıyla açıldığında kullanılır.
  void selectOnly(int id) {
    _selectedScenarioIds
      ..clear()
      ..add(id);
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
      // Sunucudan gelen detail mesajını (pin yetki, senaryo yok vb.) UI'a yansıt.
      final raw = e.toString().replaceFirst('Exception: ', '');
      setError(raw.isEmpty ? 'Senaryo güncellenemedi' : raw);
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
      // Sunucudan gelen detail mesajını (tarih eksik, pin yok vb.)
      // kullanıcıya aynen göster.
      final raw = e.toString().replaceFirst('Exception: ', '');
      setError(raw.isEmpty ? 'Senaryo hesaplanamadı' : raw);
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
