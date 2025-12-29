import 'package:flutter/foundation.dart';
import '../../core/api_service.dart';
import '../../data/models/system_data_models.dart';
import '../../core/base/base_view_model.dart';
import 'package:flutter/material.dart' show debugPrint;

class ReportViewModel extends BaseViewModel {
  final ApiService _apiService;

  ReportViewModel(this._apiService);

  RegionalReport? _currentReport;
  String _selectedRegion = 'Tümü';
  String _selectedType = 'Wind';
  RegionalSite? _focusedSite;

  RegionalReport? get report => _currentReport;
  String get selectedRegion => _selectedRegion;
  String get selectedType => _selectedType;
  RegionalSite? get focusedSite => _focusedSite;

  Future<void> fetchReport({String? region, String? type}) async {
    _selectedRegion = region ?? _selectedRegion;
    _selectedType = type ?? _selectedType;
    setBusy(true);

    try {
      _currentReport = await _apiService.fetchRegionalReport(
        region: _selectedRegion,
        type: _selectedType,
      );
    } catch (e) {
      debugPrint('Rapor yüklenirken hata: $e');
      setError('Rapor yüklenemedi');
    } finally {
      setBusy(false);
    }
  }

  void setFocusedSite(RegionalSite? site) {
    _focusedSite = site;
    notifyListeners();
  }
}
