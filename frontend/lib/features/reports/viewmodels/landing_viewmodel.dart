// lib/features/reports/viewmodels/landing_viewmodel.dart
//
// LandingTab (Raporlar/Genel Bakış) için viewmodel.
// /analysis/landing endpoint'ini çağırır, resource filter chip state'i tutar.

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/core/network/api_service.dart';

/// "all" | "wind" | "solar" | "hydro" — Resource filter chip.
class LandingViewModel extends BaseViewModel {
  final ApiService _apiService;

  LandingViewModel(this._apiService);

  AnalysisService get _svc => _apiService.analysis;

  LandingData? _data;
  String _resourceFilter = 'all'; // all | wind | solar | hydro
  String? _hoveredRegionId;

  LandingData? get data => _data;
  String get resourceFilter => _resourceFilter;
  String? get hoveredRegionId => _hoveredRegionId;

  /// Mevcut filtreye göre top-10 ili döner (overall_top'tan ya da
  /// top_provinces[res]'ten — filtreye bağlı olarak).
  List<dynamic> get filteredTop {
    if (_data == null) return const [];
    if (_resourceFilter == 'all') {
      return _data!.overallTop;
    }
    return _data!.topByResource[_resourceFilter] ?? const [];
  }

  Future<void> init() async {
    if (_data != null || isBusy) return;
    await refresh();
  }

  Future<void> refresh() async {
    setBusy(true);
    try {
      _data = await _svc.fetchLanding(topN: 10);
      setBusy(false);
    } catch (e, st) {
      debugPrint('LandingVM.fetchLanding hata: $e\n$st');
      setError(e.toString());
    }
  }

  void setResourceFilter(String f) {
    if (_resourceFilter == f) return;
    _resourceFilter = f;
    notifyListeners();
  }

  void setHoveredRegion(String? id) {
    if (_hoveredRegionId == id) return;
    _hoveredRegionId = id;
    notifyListeners();
  }
}
