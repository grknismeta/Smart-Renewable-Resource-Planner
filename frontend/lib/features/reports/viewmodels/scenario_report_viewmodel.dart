// lib/features/reports/viewmodels/scenario_report_viewmodel.dart
//
// Raporlar/Senaryo tab v3 için viewmodel.
//   - Default: tek senaryo detay (üretim + finans + pin listesi)
//   - "Kıyasla" butonu → compareMode → 2 senaryo yan yana
//
// Veri kaynakları:
//   - GET /scenarios            → senaryo listesi
//   - POST /scenarios/{id}/calculate → result_data (üretim)
//   - GET /scenarios/{id}/financials → CAPEX/NPV/IRR/LCOE/payback

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/financial_metrics.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/scenario_model.dart';

class ScenarioReportViewModel extends BaseViewModel {
  final ApiService _api;

  ScenarioReportViewModel(this._api);

  List<Scenario> _scenarios = [];
  int? _idA;
  int? _idB;
  bool _compareMode = false;

  // Finansal metrik cache — senaryo id → metrics
  final Map<int, FinancialMetrics> _financials = {};
  final Set<int> _loadingFinancials = {};
  // Calculate çağrısı yapılan senaryoların güncel hali
  final Map<int, Scenario> _calculated = {};

  // 2026-05-25 (Fix6): Senaryo paneli mini haritası için pin lokasyonları.
  // ApiService.resource.fetchPins() → tüm kullanıcı pin'leri; scenario.pinIds
  // ile filtreleyip görselleştiriyoruz.
  List<Pin> _allPins = const [];
  bool _pinsLoaded = false;

  List<Scenario> get scenarios => _scenarios;
  int? get idA => _idA;
  int? get idB => _idB;
  bool get compareMode => _compareMode;

  Scenario? get scenarioA => _resolve(_idA);
  Scenario? get scenarioB => _resolve(_idB);

  Scenario? _resolve(int? id) {
    if (id == null) return null;
    return _calculated[id] ??
        _scenarios.cast<Scenario?>().firstWhere(
              (s) => s?.id == id,
              orElse: () => null,
            );
  }

  FinancialMetrics? financialsFor(int id) => _financials[id];
  bool isLoadingFinancials(int id) => _loadingFinancials.contains(id);

  /// 2026-05-25 (Polish2): Pin haritası loading state ayrımı için.
  bool get pinsLoaded => _pinsLoaded;

  /// 2026-05-25 (G5+G6): Senaryo düzenleme dialog'u için tüm pin'lerin listesi.
  List<Pin> get allPins => _allPins;

  /// 2026-05-25 (Fix6): Verilen senaryoya ait pin'leri lat/lon ile döner.
  List<Pin> pinsForScenario(int scenarioId) {
    final scenario = _resolve(scenarioId);
    if (scenario == null || !_pinsLoaded) return const [];
    final ids = scenario.pinIds.toSet();
    return _allPins.where((p) => ids.contains(p.id)).toList();
  }

  Future<void> init({int? initialScenarioId}) async {
    if (_scenarios.isNotEmpty) return;
    setBusy(true);
    try {
      _scenarios = await _api.scenario.fetchScenarios();
      setBusy(false);
      // Pin'leri arka planda yükle — UI bloklamasın.
      _loadPins();
      if (_scenarios.isNotEmpty) {
        final firstId = initialScenarioId ?? _scenarios.first.id;
        await selectA(firstId);
      }
    } catch (e, st) {
      debugPrint('ScenarioReportVM.init hata: $e\n$st');
      setError(e.toString());
    }
  }

  Future<void> _loadPins() async {
    if (_pinsLoaded) return;
    try {
      _allPins = await _api.resource.fetchPins();
      _pinsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ScenarioReportVM._loadPins hata: $e');
    }
  }

  Future<void> selectA(int id) async {
    _idA = id;
    notifyListeners();
    await _ensureFinancials(id);
  }

  Future<void> selectB(int id) async {
    _idB = id;
    notifyListeners();
    await _ensureFinancials(id);
  }

  /// Kıyaslama modunu aç/kapat. Açılırken idB boşsa 2. senaryoyu otomatik seç.
  void toggleCompare() {
    _compareMode = !_compareMode;
    if (_compareMode && _idB == null) {
      // idA dışında ilk senaryoyu B olarak seç
      final candidate = _scenarios
          .cast<Scenario?>()
          .firstWhere((s) => s?.id != _idA, orElse: () => null);
      if (candidate != null) {
        _idB = candidate.id;
        _ensureFinancials(candidate.id);
      }
    }
    notifyListeners();
  }

  /// Senaryo için financials yüklü değilse çek.
  Future<void> _ensureFinancials(int id) async {
    if (_financials.containsKey(id) || _loadingFinancials.contains(id)) return;
    _loadingFinancials.add(id);
    notifyListeners();
    try {
      final m = await _api.scenario.fetchScenarioFinancials(id);
      _financials[id] = m;
    } catch (e) {
      debugPrint('financials($id) hata: $e');
    } finally {
      _loadingFinancials.remove(id);
      notifyListeners();
    }
  }

  /// 2026-05-25 (G5+G6): Senaryo'yu güncelle — name/date/pinIds/battery.
  /// Backend PUT /scenarios/{id} ile gönderilir, sonra otomatik recalculate
  /// (eski result_data backend tarafından temizlenir, yeni hesabı çekeriz).
  Future<void> updateScenarioFields(
    int id, {
    String? name,
    String? description,
    List<int>? pinIds,
    DateTime? startDate,
    DateTime? endDate,
    double? batteryCapacityKwh,
    double? batteryEfficiencyPct,
    double? batteryCostUsdPerKwh,
  }) async {
    final scenario = _resolve(id);
    if (scenario == null) {
      setError('Senaryo bulunamadı');
      return;
    }
    setBusy(true);
    try {
      final create = ScenarioCreate(
        name: name ?? scenario.name,
        description: description ?? scenario.description,
        pinIds: pinIds ?? scenario.pinIds,
        startDate: startDate ?? scenario.startDate,
        endDate: endDate ?? scenario.endDate,
        batteryCapacityKwh: batteryCapacityKwh ?? scenario.batteryCapacityKwh,
        batteryEfficiencyPct:
            batteryEfficiencyPct ?? scenario.batteryEfficiencyPct,
        batteryCostUsdPerKwh:
            batteryCostUsdPerKwh ?? scenario.batteryCostUsdPerKwh,
      );
      final updated = await _api.scenario.updateScenario(id, create);
      // VM cache'ini güncelle
      _calculated[id] = updated;
      // Eski result_data temizlendiği için financials cache'i de geçersiz.
      _financials.remove(id);
      // Listede de var ise üzerine yaz
      final idx = _scenarios.indexWhere((s) => s.id == id);
      if (idx >= 0) {
        _scenarios[idx] = updated;
      }
      setBusy(false);
      // Otomatik recalculate — kullanıcı tekrar butona basmasın.
      await recalculate(id);
    } catch (e, st) {
      debugPrint('updateScenarioFields($id) hata: $e\n$st');
      setError(e.toString());
    }
  }

  /// Senaryoyu yeniden hesapla (result_data + financials güncellenir).
  ///
  /// 2026-05-27 (Q1): finally bloğu ile setBusy(false) garanti — hata
  /// durumunda eski hâlinde busy=true takılı kalmasın. Ayrıca scenario
  /// listesindeki kopyayı da güncelle (eski _resolve cache miss).
  Future<void> recalculate(int id) async {
    setBusy(true);
    try {
      final updated = await _api.scenario.calculateScenario(id);
      _calculated[id] = updated;
      // Senaryo listesindeki kopyayı da güncelle — _resolve doğru objeyi
      // dönsün (önce _calculated kontrol ediyor ama yine de senkron tutalım).
      final idx = _scenarios.indexWhere((s) => s.id == id);
      if (idx >= 0) _scenarios[idx] = updated;
      _financials.remove(id); // cache invalidate
      await _ensureFinancials(id);
    } catch (e, st) {
      debugPrint('recalculate($id) hata: $e\n$st');
      setError(e.toString());
      rethrow; // Caller catch ederse SnackBar gösterebilir
    } finally {
      setBusy(false);
    }
  }

  Future<void> refresh() async {
    _scenarios = [];
    _financials.clear();
    _calculated.clear();
    // 2026-05-25 (Polish2): Pin cache'i de invalidate — refresh sırasında
    // yeni eklenmiş pin görünebilsin.
    _allPins = const [];
    _pinsLoaded = false;
    final keepA = _idA;
    _idA = null;
    _idB = null;
    await init(initialScenarioId: keepA);
  }
}
